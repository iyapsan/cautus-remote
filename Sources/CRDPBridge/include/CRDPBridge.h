#ifndef CRDPBridge_h
#define CRDPBridge_h

#include <stdbool.h>
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

// 1. Create a context
CRDPContextRef rdp_create(void);

// 2. Connect
bool rdp_connect(CRDPContextRef ctx, const char *host, int port,
                 const char *username, const char *password);

// 3. Poll events (for the event loop)
bool rdp_poll(CRDPContextRef ctx, int timeout_ms);

// 4. Send input (mouse/keyboard, minimal for now)
void rdp_send_input(CRDPContextRef ctx, int type, int code, int flags);

// 5. Disconnect
void rdp_disconnect(CRDPContextRef ctx);

// 6. Destroy context
void rdp_destroy(CRDPContextRef ctx);

// 7. Get stats
CRDPStats rdp_get_stats(CRDPContextRef ctx);

// 8. Get raw framebuffer (BGRA32)
bool rdp_get_framebuffer(CRDPContextRef ctx, void **buffer, int *width,
                         int *height, int *stride);

#endif /* CRDPBridge_h */
