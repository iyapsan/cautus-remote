#include "CRDPBridge.h"
#include <freerdp/freerdp.h>
#include <freerdp/gdi/gdi.h>
#include <freerdp/settings.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <winpr/synch.h>

typedef struct {
  rdpContext context;
  freerdp *instance;
  CRDPStats stats;
} CRDPContextImpl;

static BOOL cb_pre_connect(freerdp *instance) {
  if (!gdi_init(instance, PIXEL_FORMAT_BGRA32)) {
    return FALSE;
  }
  return TRUE;
}

static BOOL cb_post_connect(freerdp *instance) {
  rdpSettings *settings = instance->context->settings;
  CRDPContextImpl *impl = (CRDPContextImpl *)instance->context;

  impl->stats.width =
      freerdp_settings_get_uint32(settings, FreeRDP_DesktopWidth);
  impl->stats.height =
      freerdp_settings_get_uint32(settings, FreeRDP_DesktopHeight);
  impl->stats.state = 1; // Connected
  return TRUE;
}

static void cb_post_disconnect(freerdp *instance) {
  CRDPContextImpl *impl = (CRDPContextImpl *)instance->context;
  if (impl) {
    impl->stats.state = 0; // Disconnected
  }
}

static DWORD cb_verify_certificate_ex(freerdp *instance, const char *host,
                                      UINT16 port, const char *common_name,
                                      const char *subject, const char *issuer,
                                      const char *fingerprint, DWORD flags) {
  return 1; // Auto-accept for spike
}

CRDPContextRef rdp_create(void) {
  freerdp *instance = freerdp_new();
  if (!instance) {
    return NULL;
  }

  instance->PreConnect = cb_pre_connect;
  instance->PostConnect = cb_post_connect;
  instance->PostDisconnect = cb_post_disconnect;
  instance->VerifyCertificateEx = cb_verify_certificate_ex;

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
                 const char *username, const char *password) {
  if (!ctx)
    return false;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  freerdp *instance = impl->instance;
  rdpSettings *settings = instance->context->settings;

  freerdp_settings_set_string(settings, FreeRDP_ServerHostname, host);
  freerdp_settings_set_uint32(settings, FreeRDP_ServerPort, (UINT32)port);
  freerdp_settings_set_string(settings, FreeRDP_Username, username);
  freerdp_settings_set_string(settings, FreeRDP_Password, password);
  freerdp_settings_set_bool(settings, FreeRDP_IgnoreCertificate, TRUE);

  freerdp_settings_set_uint32(settings, FreeRDP_DesktopWidth, 1280);
  freerdp_settings_set_uint32(settings, FreeRDP_DesktopHeight, 720);

  if (!freerdp_connect(instance)) {
    return false;
  }
  return true;
}

bool rdp_poll(CRDPContextRef ctx, int timeout_ms) {
  if (!ctx)
    return false;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  freerdp *instance = impl->instance;

  HANDLE handles[64];
  DWORD nCount = freerdp_get_event_handles(instance->context, handles, 64);
  if (nCount == 0)
    return false;

  DWORD status = WaitForMultipleObjects(nCount, handles, FALSE, timeout_ms);
  if (status == WAIT_FAILED)
    return false;

  if (!freerdp_check_event_handles(instance->context)) {
    return false;
  }

  impl->stats.fps++; // Simple counter for now
  return true;
}

void rdp_send_input(CRDPContextRef ctx, int type, int code, int flags) {
  // Scaffold for later
}

void rdp_disconnect(CRDPContextRef ctx) {
  if (!ctx)
    return;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  freerdp_disconnect(impl->instance);
}

void rdp_destroy(CRDPContextRef ctx) {
  if (!ctx)
    return;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  if (impl->instance) {
    gdi_free(impl->instance);
    freerdp_context_free(impl->instance);
    freerdp_free(impl->instance);
  }
  free(impl);
}

CRDPStats rdp_get_stats(CRDPContextRef ctx) {
  CRDPStats empty = {0};
  if (!ctx)
    return empty;
  CRDPContextImpl *impl = (CRDPContextImpl *)ctx;
  return impl->stats;
}
