#include "CRDPBridge.h"
#include <freerdp/client.h>
#include <freerdp/client/channels.h>
#include <freerdp/client/cliprdr.h>
#include <freerdp/event.h>
#include <freerdp/freerdp.h>
#include <freerdp/gdi/gdi.h>
#include <freerdp/settings.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <winpr/clipboard.h>
#include <winpr/collections.h>
#include <winpr/synch.h>
#include <winpr/wlog.h>

typedef struct {
  rdpContext context;
  freerdp *instance;
  CRDPStats stats;
  CRDPVerifyX509Callback verify_x509_cb;
  // Clipboard
  CliprdrClientContext *cliprdr;
  CRDPClipboardTextReceivedCallback clipboard_received_cb;
  CRDPClipboardDataRequestCallback clipboard_request_cb;
  // Pending outgoing clipboard text (Mac → Windows)
  char *pending_clip_text; // UTF-8
  size_t pending_clip_len;
  BOOL pending_clip_ready; // TRUE once Windows asked for data
} CRDPContextImpl;

// Forward declarations for cliprdr callbacks (defined later in this file)
static UINT cliprdr_monitor_ready(CliprdrClientContext *,
                                  const CLIPRDR_MONITOR_READY *);
static UINT cliprdr_server_format_list(CliprdrClientContext *,
                                       const CLIPRDR_FORMAT_LIST *);
static UINT
cliprdr_server_format_data_response(CliprdrClientContext *,
                                    const CLIPRDR_FORMAT_DATA_RESPONSE *);
static UINT
cliprdr_server_format_data_request(CliprdrClientContext *,
                                   const CLIPRDR_FORMAT_DATA_REQUEST *);

// Called by the PubSub ChannelConnected event when cliprdr channel is ready
static void on_channel_connected(void *context,
                                 const ChannelConnectedEventArgs *e) {
  fprintf(stderr,
          "[CRDPBridge] on_channel_connected: name=%s pInterface=%p ctx=%p\n",
          (e && e->name) ? e->name : "(null)", e ? e->pInterface : NULL,
          context);
  CRDPContextImpl *impl = (CRDPContextImpl *)context;
  if (!e || !e->name || !e->pInterface)
    return;
  if (strcmp(e->name, CLIPRDR_CHANNEL_NAME) == 0) {
    CliprdrClientContext *cliprdr = (CliprdrClientContext *)e->pInterface;
    impl->cliprdr = cliprdr;
    cliprdr->custom = impl;
    cliprdr->MonitorReady = cliprdr_monitor_ready;
    cliprdr->ServerFormatList = cliprdr_server_format_list;
    cliprdr->ServerFormatDataResponse = cliprdr_server_format_data_response;
    cliprdr->ServerFormatDataRequest = cliprdr_server_format_data_request;
    fprintf(stderr,
            "[CRDPBridge] cliprdr context acquired via ChannelConnected\n");
  }
}

// External declaration of the statically linked cliprdr channel entry point
BOOL cliprdr_VirtualChannelEntryEx(PCHANNEL_ENTRY_POINTS_EX pEntryPoints,
                                   PVOID pInitHandle);

// Called by ChannelAttached event — VirtualChannelEntryEx plugins may use this
static void on_channel_attached(void *context,
                                const ChannelAttachedEventArgs *e) {
  fprintf(stderr, "[CRDPBridge] on_channel_attached: name=%s pInterface=%p\n",
          (e && e->name) ? e->name : "(null)", e ? e->pInterface : NULL);
  CRDPContextImpl *impl = (CRDPContextImpl *)context;
  if (!e || !e->name || !e->pInterface)
    return;
  if (strcmp(e->name, CLIPRDR_CHANNEL_NAME) == 0) {
    CliprdrClientContext *cliprdr = (CliprdrClientContext *)e->pInterface;
    impl->cliprdr = cliprdr;
    cliprdr->custom = impl;
    cliprdr->MonitorReady = cliprdr_monitor_ready;
    cliprdr->ServerFormatList = cliprdr_server_format_list;
    cliprdr->ServerFormatDataResponse = cliprdr_server_format_data_response;
    cliprdr->ServerFormatDataRequest = cliprdr_server_format_data_request;
    fprintf(stderr,
            "[CRDPBridge] cliprdr context acquired via ChannelAttached\n");
  }
}

static BOOL custom_load_channels(freerdp *instance) {
  fprintf(stderr, "[CRDPBridge] custom_load_channels called!\n");
  int rc = freerdp_channels_client_load_ex(instance->context->channels,
                                           instance->context->settings,
                                           cliprdr_VirtualChannelEntryEx, NULL);
  fprintf(stderr, "[CRDPBridge] custom_load_channels: cliprdr load rc=%d\n",
          rc);
  return TRUE;
}

static BOOL cb_pre_connect(freerdp *instance) {
  // Subscribe to both ChannelConnected and ChannelAttached events
  // (different cliprdr build configs fire different events)
  PubSub_SubscribeChannelConnected(instance->context->pubSub,
                                   on_channel_connected);
  PubSub_SubscribeChannelAttached(instance->context->pubSub,
                                  on_channel_attached);

  if (!gdi_init(instance, PIXEL_FORMAT_BGRA32)) {
    return FALSE;
  }
  return TRUE;
}

static BOOL cb_post_connect(freerdp *instance) {
  rdpSettings *settings = instance->context->settings;
  CRDPContextImpl *impl = (CRDPContextImpl *)instance->context;

  fprintf(stderr, "[CRDPBridge] cb_post_connect: StaticChannelCount=%u\n",
          freerdp_settings_get_uint32(settings, FreeRDP_StaticChannelCount));

  impl->stats.width =
      freerdp_settings_get_uint32(settings, FreeRDP_DesktopWidth);
  impl->stats.height =
      freerdp_settings_get_uint32(settings, FreeRDP_DesktopHeight);
  impl->stats.state = 1; // Connected
  // Note: cliprdr context is set up via PubSub ChannelConnected event (see
  // on_channel_connected)
  return TRUE;
}

// ── Clipboard (cliprdr)
// ───────────────────────────────────────────────────────

// CF_UNICODETEXT = 13 (standard Windows format ID)
#define CF_UNICODETEXT_ID 13

// Helper: UTF-16LE → UTF-8
static char *utf16le_to_utf8(const BYTE *src, size_t src_bytes,
                             size_t *out_len) {
  if (!src || src_bytes == 0)
    return NULL;
  // Count UTF-16LE code units (strip trailing NUL if present)
  size_t nchars = src_bytes / 2;
  while (nchars > 0 && src[(nchars - 1) * 2] == 0 &&
         src[(nchars - 1) * 2 + 1] == 0)
    nchars--;
  // Allocate worst-case UTF-8 buffer (4 bytes per code point)
  size_t cap = nchars * 4 + 1;
  char *dst = (char *)malloc(cap);
  if (!dst)
    return NULL;
  size_t di = 0;
  for (size_t i = 0; i < nchars; i++) {
    uint32_t cp = (uint32_t)src[i * 2] | ((uint32_t)src[i * 2 + 1] << 8);
    // Handle surrogate pairs
    if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < nchars) {
      uint32_t lo =
          (uint32_t)src[(i + 1) * 2] | ((uint32_t)src[(i + 1) * 2 + 1] << 8);
      if (lo >= 0xDC00 && lo <= 0xDFFF) {
        cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
        i++;
      }
    }
    if (cp < 0x80) {
      dst[di++] = (char)cp;
    } else if (cp < 0x800) {
      dst[di++] = (char)(0xC0 | (cp >> 6));
      dst[di++] = (char)(0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
      dst[di++] = (char)(0xE0 | (cp >> 12));
      dst[di++] = (char)(0x80 | ((cp >> 6) & 0x3F));
      dst[di++] = (char)(0x80 | (cp & 0x3F));
    } else {
      dst[di++] = (char)(0xF0 | (cp >> 18));
      dst[di++] = (char)(0x80 | ((cp >> 12) & 0x3F));
      dst[di++] = (char)(0x80 | ((cp >> 6) & 0x3F));
      dst[di++] = (char)(0x80 | (cp & 0x3F));
    }
  }
  dst[di] = '\0';
  if (out_len)
    *out_len = di;
  return dst;
}

// Helper: UTF-8 → UTF-16LE
static BYTE *utf8_to_utf16le(const char *src, size_t src_len,
                             size_t *out_bytes) {
  // Allocate worst-case (each UTF-8 char <-> 2 UTF-16 code units + NUL)
  size_t cap = (src_len + 1) * 2;
  BYTE *dst = (BYTE *)calloc(cap, 1);
  if (!dst)
    return NULL;
  size_t si = 0, di = 0;
  while (si < src_len) {
    uint32_t cp = 0;
    unsigned char c = (unsigned char)src[si];
    if (c < 0x80) {
      cp = c;
      si += 1;
    } else if (c < 0xE0) {
      cp = (c & 0x1F) << 6 | ((unsigned char)src[si + 1] & 0x3F);
      si += 2;
    } else if (c < 0xF0) {
      cp = (c & 0x0F) << 12 | ((unsigned char)src[si + 1] & 0x3F) << 6 |
           ((unsigned char)src[si + 2] & 0x3F);
      si += 3;
    } else {
      cp = (c & 0x07) << 18 | ((unsigned char)src[si + 1] & 0x3F) << 12 |
           ((unsigned char)src[si + 2] & 0x3F) << 6 |
           ((unsigned char)src[si + 3] & 0x3F);
      si += 4;
    }
    if (cp < 0x10000) {
      dst[di++] = cp & 0xFF;
      dst[di++] = (cp >> 8) & 0xFF;
    } else {
      cp -= 0x10000;
      uint16_t hi = 0xD800 | (cp >> 10), lo = 0xDC00 | (cp & 0x3FF);
      dst[di++] = hi & 0xFF;
      dst[di++] = (hi >> 8) & 0xFF;
      dst[di++] = lo & 0xFF;
      dst[di++] = (lo >> 8) & 0xFF;
    }
  }
  dst[di++] = 0;
  dst[di++] = 0; // NUL terminator
  if (out_bytes)
    *out_bytes = di;
  return dst;
}

// Called by FreeRDP when the server clipboard channel is ready
static UINT cliprdr_monitor_ready(CliprdrClientContext *ctx,
                                  const CLIPRDR_MONITOR_READY *monitor_ready) {
  (void)monitor_ready;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx->custom;

  // Send our capabilities
  CLIPRDR_GENERAL_CAPABILITY_SET capSet = {
      .capabilitySetType = CB_CAPSTYPE_GENERAL,
      .capabilitySetLength = CB_CAPSTYPE_GENERAL_LEN,
      .version = CB_CAPS_VERSION_2,
      .generalFlags = CB_USE_LONG_FORMAT_NAMES,
  };
  CLIPRDR_CAPABILITIES caps = {
      .cCapabilitiesSets = 1,
      .capabilitySets = (CLIPRDR_CAPABILITY_SET *)&capSet,
  };
  ctx->ClientCapabilities(ctx, &caps);

  // Advertise we have CF_UNICODETEXT on the Mac clipboard
  CLIPRDR_FORMAT fmt = {.formatId = CF_UNICODETEXT_ID, .formatName = NULL};
  CLIPRDR_FORMAT_LIST fmtList = {.numFormats = 1, .formats = &fmt};
  ctx->ClientFormatList(ctx, &fmtList);
  fprintf(
      stderr,
      "[CRDPBridge] cliprdr: MonitorReady, capabilities + format list sent\n");
  return CHANNEL_RC_OK;
}

// Called when Windows advertises its clipboard format list (Windows copied
// something)
static UINT cliprdr_server_format_list(CliprdrClientContext *ctx,
                                       const CLIPRDR_FORMAT_LIST *formatList) {
  // Acknowledge the server's format list
  CLIPRDR_FORMAT_LIST_RESPONSE resp = {.common.msgFlags = CB_RESPONSE_OK};
  ctx->ClientFormatListResponse(ctx, &resp);

  // Check if CF_UNICODETEXT is in the list and request it
  for (UINT32 i = 0; i < formatList->numFormats; i++) {
    if (formatList->formats[i].formatId == CF_UNICODETEXT_ID) {
      CLIPRDR_FORMAT_DATA_REQUEST req = {.requestedFormatId =
                                             CF_UNICODETEXT_ID};
      ctx->ClientFormatDataRequest(ctx, &req);
      fprintf(stderr,
              "[CRDPBridge] cliprdr: requested CF_UNICODETEXT from server\n");
      break;
    }
  }
  return CHANNEL_RC_OK;
}

// Called when Windows responds with the actual clipboard data we requested
static UINT cliprdr_server_format_data_response(
    CliprdrClientContext *ctx, const CLIPRDR_FORMAT_DATA_RESPONSE *response) {
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx->custom;
  if (!impl->clipboard_received_cb)
    return CHANNEL_RC_OK;
  if (response->common.msgFlags & CB_RESPONSE_FAIL)
    return CHANNEL_RC_OK;
  if (!response->requestedFormatData)
    return CHANNEL_RC_OK;

  size_t data_len = response->common.dataLen;
  size_t utf8_len = 0;
  char *utf8 =
      utf16le_to_utf8(response->requestedFormatData, data_len, &utf8_len);
  if (utf8) {
    impl->clipboard_received_cb((CRDPContextRef)impl, utf8, utf8_len);
    free(utf8);
  }
  return CHANNEL_RC_OK;
}

// Called when Windows wants the Mac clipboard data
static UINT
cliprdr_server_format_data_request(CliprdrClientContext *ctx,
                                   const CLIPRDR_FORMAT_DATA_REQUEST *request) {
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx->custom;

  // Only handle text requests
  if (request->requestedFormatId != CF_UNICODETEXT_ID) {
    CLIPRDR_FORMAT_DATA_RESPONSE resp = {.common.msgFlags = CB_RESPONSE_FAIL};
    ctx->ClientFormatDataResponse(ctx, &resp);
    return CHANNEL_RC_OK;
  }

  char *utf8_text = NULL;
  if (impl->clipboard_request_cb) {
    utf8_text = impl->clipboard_request_cb((CRDPContextRef)impl);
  }

  if (!utf8_text) {
    CLIPRDR_FORMAT_DATA_RESPONSE resp = {.common.msgFlags = CB_RESPONSE_FAIL};
    ctx->ClientFormatDataResponse(ctx, &resp);
    return CHANNEL_RC_OK;
  }

  size_t utf16_bytes = 0;
  BYTE *utf16 = utf8_to_utf16le(utf8_text, strlen(utf8_text), &utf16_bytes);
  free(utf8_text);

  CLIPRDR_FORMAT_DATA_RESPONSE resp = {
      .common.msgFlags = CB_RESPONSE_OK,
      .common.dataLen = (UINT32)utf16_bytes,
      .requestedFormatData = utf16,
  };
  ctx->ClientFormatDataResponse(ctx, &resp);
  free(utf16);
  return CHANNEL_RC_OK;
}

static void cb_post_disconnect(freerdp *instance) {
  CRDPContextImpl *impl = (CRDPContextImpl *)instance->context;
  if (impl) {
    impl->stats.state = 0; // Disconnected
    impl->cliprdr = NULL;
    if (impl->pending_clip_text) {
      free(impl->pending_clip_text);
      impl->pending_clip_text = NULL;
    }
  }
}

static int cb_verify_x509_certificate(freerdp *instance, const BYTE *data,
                                      size_t length, const char *hostname,
                                      UINT16 port, DWORD flags) {
  fprintf(stderr, "[CRDPBridge] cb_verify_x509_certificate triggered for %s\n",
          hostname ? hostname : "unknown");
  CRDPContextImpl *impl = (CRDPContextImpl *)instance->context;
  if (impl && impl->verify_x509_cb) {
    bool accepted = impl->verify_x509_cb((CRDPContextRef)impl, hostname, port,
                                         (const uint8_t *)data, length);
    fprintf(stderr, "[CRDPBridge] Swift callback returned: %d\n", accepted);
    // Return 1 to accept and store, 0 to reject.
    return accepted ? 1 : 0;
  }
  return 0; // Default deny
}

CRDPContextRef rdp_create(void) {
  freerdp *instance = freerdp_new();
  if (!instance) {
    return NULL;
  }

  instance->PreConnect = cb_pre_connect;
  instance->PostConnect = cb_post_connect;
  instance->PostDisconnect = cb_post_disconnect;
  instance->VerifyX509Certificate = cb_verify_x509_certificate;

  instance->ContextSize = sizeof(CRDPContextImpl);

  if (!freerdp_context_new(instance)) {
    freerdp_free(instance);
    return NULL;
  }

  CRDPContextImpl *impl = (CRDPContextImpl *)instance->context;
  impl->instance = instance;
  impl->stats.state = 0;

  return (CRDPContextRef)impl;
}

bool rdp_connect(CRDPContextRef ctx, const char *host, int port,
                 const char *username, const char *password,
                 const char *gw_host, const char *gw_user, const char *gw_pass,
                 const char *gw_domain, int gw_usage_method,
                 bool gw_bypass_local, bool gw_use_same_creds,
                 bool ignore_cert) {
  if (!ctx)
    return false;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  freerdp *instance = impl->instance;
  rdpSettings *settings = instance->context->settings;

  // Primary Host Connection
  freerdp_settings_set_string(settings, FreeRDP_ServerHostname, host);
  freerdp_settings_set_uint32(settings, FreeRDP_ServerPort, (UINT32)port);
  freerdp_settings_set_string(settings, FreeRDP_Username, username);
  freerdp_settings_set_string(settings, FreeRDP_Password, password);

  // RD Gateway Routing Handshake
  if (gw_host && strlen(gw_host) > 0) {
    freerdp_settings_set_bool(settings, FreeRDP_GatewayEnabled, TRUE);
    freerdp_settings_set_uint32(settings, FreeRDP_GatewayUsageMethod,
                                gw_usage_method);
    freerdp_settings_set_bool(settings, FreeRDP_GatewayUseSameCredentials,
                              gw_use_same_creds);
    freerdp_settings_set_bool(settings, FreeRDP_GatewayBypassLocal,
                              gw_bypass_local);

    freerdp_settings_set_string(settings, FreeRDP_GatewayHostname, gw_host);

    if (gw_user && strlen(gw_user) > 0) {
      freerdp_settings_set_string(settings, FreeRDP_GatewayUsername, gw_user);
    }
    if (gw_pass && strlen(gw_pass) > 0) {
      freerdp_settings_set_string(settings, FreeRDP_GatewayPassword, gw_pass);
    }
    if (gw_domain && strlen(gw_domain) > 0) {
      freerdp_settings_set_string(settings, FreeRDP_GatewayDomain, gw_domain);
    }
  }
  freerdp_settings_set_bool(settings, FreeRDP_IgnoreCertificate, ignore_cert);
  freerdp_settings_set_bool(settings, FreeRDP_AutoAcceptCertificate, FALSE);
  freerdp_settings_set_bool(settings, FreeRDP_AutoDenyCertificate, FALSE);

  freerdp_settings_set_bool(settings, FreeRDP_AutoReconnectionEnabled, TRUE);
  freerdp_settings_set_uint32(settings, FreeRDP_AutoReconnectMaxRetries, 20);

  freerdp_settings_set_uint32(settings, FreeRDP_DesktopWidth, 1280);
  freerdp_settings_set_uint32(settings, FreeRDP_DesktopHeight, 720);

  // Enable clipboard sharing via the cliprdr channel
  freerdp_settings_set_bool(settings, FreeRDP_RedirectClipboard, TRUE);

  const char *cliprdr_args[] = {"cliprdr"};
  freerdp_client_add_static_channel(settings, 1, cliprdr_args);
  freerdp_client_add_dynamic_channel(settings, 1, cliprdr_args);

  // Override LoadChannels with our custom loader for static symbols
  instance->LoadChannels = custom_load_channels;

  if (!freerdp_connect(instance)) {
    fprintf(stderr, "[CRDPBridge] freerdp_connect failed!\n");
    return false;
  }
  fprintf(stderr, "[CRDPBridge] freerdp_connect succeeded.\n");
  return true;
}

bool rdp_poll(CRDPContextRef ctx, int timeout_ms) {
  if (!ctx)
    return false;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  freerdp *instance = impl->instance;

  HANDLE handles[64];
  DWORD nCount = freerdp_get_event_handles(instance->context, handles, 64);
  if (nCount == 0) {
    fprintf(stderr,
            "[CRDPBridge] freerdp_get_event_handles returned 0 handles!\n");
    return false;
  }

  DWORD status = WaitForMultipleObjects(nCount, handles, FALSE, timeout_ms);
  if (status == WAIT_FAILED) {
    fprintf(stderr, "[CRDPBridge] WaitForMultipleObjects failed!\n");
    return false;
  }

  if (!freerdp_check_event_handles(instance->context)) {
    fprintf(stderr,
            "[CRDPBridge] freerdp_check_event_handles failed! error=0x%08x\n",
            freerdp_get_last_error(instance->context));
    return false;
  }

  if (!freerdp_channels_check_fds(instance->context->channels, instance)) {
    fprintf(stderr, "[CRDPBridge] freerdp_channels_check_fds failed!\n");
    return false;
  }

  // Lazily acquire cliprdr context once the channel has been initialised
  // (FreeRDP registers it in the static channel table after post-connect setup)
  if (!impl->cliprdr) {
    CliprdrClientContext *cliprdr =
        (CliprdrClientContext *)freerdp_channels_get_static_channel_interface(
            instance->context->channels, CLIPRDR_CHANNEL_NAME);
    if (cliprdr) {
      impl->cliprdr = cliprdr;
      cliprdr->custom = impl;
      cliprdr->MonitorReady = cliprdr_monitor_ready;
      cliprdr->ServerFormatList = cliprdr_server_format_list;
      cliprdr->ServerFormatDataResponse = cliprdr_server_format_data_response;
      cliprdr->ServerFormatDataRequest = cliprdr_server_format_data_request;
      fprintf(stderr, "[CRDPBridge] cliprdr context acquired in poll loop\n");
    }
  }

  impl->stats.fps++; // Simple counter for now
  return true;
}

void rdp_send_input_keyboard(CRDPContextRef ctx, uint16_t flags,
                             uint16_t scancode) {
  if (!ctx)
    return;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  freerdp *instance = impl->instance;
  if (instance && instance->context && instance->context->input) {
    freerdp_input_send_keyboard_event(instance->context->input, flags,
                                      (UINT8)scancode);
  }
}

void rdp_send_input_mouse(CRDPContextRef ctx, uint16_t flags, uint16_t x,
                          uint16_t y) {
  if (!ctx)
    return;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  freerdp *instance = impl->instance;
  if (instance && instance->context && instance->context->input) {
    freerdp_input_send_mouse_event(instance->context->input, flags, x, y);
  }
}

void rdp_disconnect(CRDPContextRef ctx) {
  if (!ctx)
    return;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  freerdp_disconnect(impl->instance);
}

void rdp_set_certificate_callbacks(CRDPContextRef ctx,
                                   CRDPVerifyX509Callback verify_cb) {
  if (!ctx)
    return;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  impl->verify_x509_cb = verify_cb;
}

void rdp_set_clipboard_callbacks(CRDPContextRef ctx,
                                 CRDPClipboardTextReceivedCallback received_cb,
                                 CRDPClipboardDataRequestCallback request_cb) {
  if (!ctx)
    return;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  impl->clipboard_received_cb = received_cb;
  impl->clipboard_request_cb = request_cb;
}

void rdp_send_clipboard_text(CRDPContextRef ctx, const char *utf8_text,
                             size_t length) {
  if (!ctx || !utf8_text || length == 0)
    return;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  if (!impl->cliprdr)
    return;

  // Store the pending text; it will be served when Windows sends
  // ServerFormatDataRequest
  if (impl->pending_clip_text)
    free(impl->pending_clip_text);
  impl->pending_clip_text = (char *)malloc(length + 1);
  if (!impl->pending_clip_text)
    return;
  memcpy(impl->pending_clip_text, utf8_text, length);
  impl->pending_clip_text[length] = '\0';
  impl->pending_clip_len = length;

  // Advertise CF_UNICODETEXT to Windows — it will request the data shortly
  CLIPRDR_FORMAT fmt = {.formatId = CF_UNICODETEXT_ID, .formatName = NULL};
  CLIPRDR_FORMAT_LIST fmtList = {.numFormats = 1, .formats = &fmt};
  impl->cliprdr->ClientFormatList(impl->cliprdr, &fmtList);
  fprintf(stderr,
          "[CRDPBridge] rdp_send_clipboard_text: advertised format list\n");
}

void rdp_destroy(CRDPContextRef ctx) {
  if (!ctx)
    return;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  freerdp *instance = impl->instance; // Cache before `impl` is freed
  if (instance) {
    gdi_free(instance);
    freerdp_context_free(instance); // This internally frees `instance->context`
                                    // (which is `impl`)
    freerdp_free(instance);
  }
}

CRDPStats rdp_get_stats(CRDPContextRef ctx) {
  CRDPStats empty = {0};
  if (!ctx)
    return empty;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  return impl->stats;
}

uint32_t rdp_get_last_error(CRDPContextRef ctx) {
  if (!ctx)
    return 0;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  if (impl->instance && impl->instance->context) {
    return freerdp_get_last_error(impl->instance->context);
  }
  return 0;
}

bool rdp_get_framebuffer(CRDPContextRef ctx, void **buffer, int *width,
                         int *height, int *stride) {
  if (!ctx || !buffer || !width || !height || !stride)
    return false;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  freerdp *instance = impl->instance;

  if (!instance || !instance->context || !instance->context->gdi)
    return false;

  rdpGdi *gdi = instance->context->gdi;
  *buffer = gdi->primary_buffer;
  *width = gdi->width;
  *height = gdi->height;
  *stride = gdi->stride;

  return (*buffer != NULL);
}

// ----------------------------------------------------
// Debugging and Validation Helpers
// ----------------------------------------------------

void rdp_print_env_report(void) {
#include <freerdp/version.h>
  printf("\n=== CautusRDP Environment Report ===\n");
  printf("FreeRDP Version: %s\n", FREERDP_VERSION_FULL);
  printf("FreeRDP API Version: %s\n", FREERDP_API_VERSION);
  printf(
      "Gateway Support (Compile Time): YES (via direct settings injection)\n");
  printf("====================================\n\n");
}

void rdp_print_config(CRDPContextRef ctx) {
  if (!ctx)
    return;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  rdpSettings *settings = impl->instance->context->settings;

  printf("\n=== CautusRDP Negotiated Config ===\n");
  printf("Target Host:      %s:%d\n",
         freerdp_settings_get_string(settings, FreeRDP_ServerHostname),
         freerdp_settings_get_uint32(settings, FreeRDP_ServerPort));
  printf("Target User:      %s\n",
         freerdp_settings_get_string(settings, FreeRDP_Username));
  printf("Target Domain:    %s\n",
         freerdp_settings_get_string(settings, FreeRDP_Domain)
             ? freerdp_settings_get_string(settings, FreeRDP_Domain)
             : "(none)");

  BOOL gwEnabled = freerdp_settings_get_bool(settings, FreeRDP_GatewayEnabled);
  printf("\n-- Gateway Settings --\n");
  printf("Gateway Enabled:  %s\n", gwEnabled ? "YES" : "NO");

  if (gwEnabled) {
    printf("Gateway Host:     %s\n",
           freerdp_settings_get_string(settings, FreeRDP_GatewayHostname));
    printf("Gateway User:     %s\n",
           freerdp_settings_get_string(settings, FreeRDP_GatewayUsername));
    printf("Gateway Domain:   %s\n",
           freerdp_settings_get_string(settings, FreeRDP_GatewayDomain)
               ? freerdp_settings_get_string(settings, FreeRDP_GatewayDomain)
               : "(none)");
    printf("Gateway Method:   %u (1=Direct, 2=RPC, 3=HTTP)\n",
           freerdp_settings_get_uint32(settings, FreeRDP_GatewayUsageMethod));
    printf("Gateway Bypass L: %s\n",
           freerdp_settings_get_bool(settings, FreeRDP_GatewayBypassLocal)
               ? "YES"
               : "NO");
  }
  printf("===================================\n\n");
}
