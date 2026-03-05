#ifndef CRDPBridge_h
#define CRDPBridge_h

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef void *CRDPContextRef;

typedef struct {
  uint32_t width;
  uint32_t height;
  uint32_t bpp;
  uint32_t requested_protocols;
  uint32_t negotiated_protocol;
} CRDPContextInfo;

typedef struct {
  uint32_t fps;
  uint32_t dropped_frames;
  uint32_t bytes_copied;
  uint32_t width;
  uint32_t height;
  int state;
} CRDPStats;

// Certificate Callbacks
typedef bool (*CRDPVerifyX509Callback)(CRDPContextRef ctx, const char *hostname,
                                       uint16_t port, const uint8_t *pem_data,
                                       size_t pem_length);

// Clipboard Callbacks
// Called when Windows sends text to the Mac clipboard
typedef void (*CRDPClipboardTextReceivedCallback)(CRDPContextRef ctx,
                                                  const char *utf8_text,
                                                  size_t length);

// 1. Create a context
CRDPContextRef rdp_create(void);

// 2. Connect
bool rdp_connect(CRDPContextRef ctx, const char *host, int port,
                 const char *username, const char *password,
                 const char *gw_host, const char *gw_user, const char *gw_pass,
                 const char *gw_domain, int gw_usage_method,
                 bool gw_bypass_local, bool gw_use_same_creds,
                 bool ignore_cert);

// 3. Poll events (for the event loop)
bool rdp_poll(CRDPContextRef ctx, int timeout_ms);

// 4. Send input
void rdp_send_input_keyboard(CRDPContextRef ctx, uint16_t flags,
                             uint16_t scancode);
void rdp_send_input_mouse(CRDPContextRef ctx, uint16_t flags, uint16_t x,
                          uint16_t y);

// 5. Disconnect
void rdp_disconnect(CRDPContextRef ctx);

// 5b. Set Callbacks
void rdp_set_certificate_callbacks(CRDPContextRef ctx,
                                   CRDPVerifyX509Callback verify_cb);
void rdp_set_clipboard_callbacks(CRDPContextRef ctx,
                                 CRDPClipboardTextReceivedCallback received_cb);

// 5c. Push Mac clipboard text to Windows
void rdp_send_clipboard_text(CRDPContextRef ctx, const char *utf8_text,
                             size_t length);

// 6. Destroy context
void rdp_destroy(CRDPContextRef ctx);

// 7. Get stats
CRDPStats rdp_get_stats(CRDPContextRef ctx);

// 8. Get raw framebuffer (BGRA32)
bool rdp_get_framebuffer(CRDPContextRef ctx, void **buffer, int *width,
                         int *height, int *stride);

// 8b. Notify that a frame was presented to the UI (for watchdog)
void rdp_mark_frame_presented(CRDPContextRef ctx);

// 9. Debugging and Validation
void rdp_print_config(CRDPContextRef ctx);
void rdp_print_env_report(void);

#endif /* CRDPBridge_h */
