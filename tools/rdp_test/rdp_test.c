/*
 * tools/rdp_test/rdp_test.c
 *
 * Minimal FreeRDP test binary.
 * Connects to an RDP server, runs an event loop for a specified duration,
 * then disconnects cleanly.
 *
 * Usage: rdp_test --host <ip> --user <user> --pass <pass> [--port <port>]
 * [--duration <sec>]
 */

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <freerdp/channels/channels.h>
#include <freerdp/freerdp.h>
#include <freerdp/gdi/gdi.h>
#include <freerdp/settings.h>
#include <winpr/synch.h>
#include <winpr/thread.h>

static volatile int g_running = 1;

static void signal_handler(int sig) {
  (void)sig;
  g_running = 0;
  printf("[rdp_test] Signal received, shutting down...\n");
}

/* Callbacks */
static BOOL cb_pre_connect(freerdp *instance) {
  rdpSettings *settings = instance->context->settings;
  printf("[rdp_test] PreConnect: %s:%u\n",
         freerdp_settings_get_string(settings, FreeRDP_ServerHostname),
         freerdp_settings_get_uint32(settings, FreeRDP_ServerPort));

  /* Enable GDI for framebuffer access */
  if (!gdi_init(instance, PIXEL_FORMAT_BGRA32)) {
    printf("[rdp_test] ERROR: gdi_init failed\n");
    return FALSE;
  }
  return TRUE;
}

static BOOL cb_post_connect(freerdp *instance) {
  rdpSettings *settings = instance->context->settings;
  uint32_t w = freerdp_settings_get_uint32(settings, FreeRDP_DesktopWidth);
  uint32_t h = freerdp_settings_get_uint32(settings, FreeRDP_DesktopHeight);
  printf("[rdp_test] PostConnect: desktop=%ux%u\n", w, h);

  /* Log negotiated security */
  uint32_t sec =
      freerdp_settings_get_uint32(settings, FreeRDP_RequestedProtocols);
  printf("[rdp_test] Security protocol: 0x%x\n", sec);

  return TRUE;
}

static void cb_post_disconnect(freerdp *instance) {
  (void)instance;
  printf("[rdp_test] PostDisconnect\n");
}

static BOOL cb_end_paint(rdpContext *context) {
  /* No-op: we don't render in this test */
  (void)context;
  return TRUE;
}

static DWORD cb_verify_certificate(freerdp *instance, const char *common_name,
                                   const char *subject, const char *issuer,
                                   const char *fingerprint,
                                   BOOL host_mismatch) {
  (void)instance;
  (void)common_name;
  (void)subject;
  (void)issuer;
  (void)fingerprint;
  (void)host_mismatch;
  printf("[rdp_test] Certificate: CN=%s (auto-accepting)\n",
         common_name ? common_name : "?");
  return 1; /* Accept */
}

static DWORD cb_verify_certificate_ex(freerdp *instance, const char *host,
                                      UINT16 port, const char *common_name,
                                      const char *subject, const char *issuer,
                                      const char *fingerprint, DWORD flags) {
  (void)instance;
  (void)host;
  (void)port;
  (void)common_name;
  (void)subject;
  (void)issuer;
  (void)fingerprint;
  (void)flags;
  printf("[rdp_test] CertificateEx: host=%s:%u CN=%s (auto-accepting)\n",
         host ? host : "?", port, common_name ? common_name : "?");
  return 1; /* Accept */
}

static void print_usage(void) {
  printf("Usage: rdp_test --host <ip> --user <user> --pass <pass> [--port "
         "<port>] [--duration <sec>]\n");
}

int main(int argc, char *argv[]) {
  const char *host = NULL;
  const char *user = NULL;
  const char *pass = NULL;
  int port = 3389;
  int duration = 10; /* seconds */

  /* Parse args */
  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--host") == 0 && i + 1 < argc)
      host = argv[++i];
    else if (strcmp(argv[i], "--user") == 0 && i + 1 < argc)
      user = argv[++i];
    else if (strcmp(argv[i], "--pass") == 0 && i + 1 < argc)
      pass = argv[++i];
    else if (strcmp(argv[i], "--port") == 0 && i + 1 < argc)
      port = atoi(argv[++i]);
    else if (strcmp(argv[i], "--duration") == 0 && i + 1 < argc)
      duration = atoi(argv[++i]);
    else {
      print_usage();
      return 1;
    }
  }

  if (!host || !user || !pass) {
    print_usage();
    return 1;
  }

  signal(SIGINT, signal_handler);
  signal(SIGTERM, signal_handler);

  printf("[rdp_test] Connecting to %s:%d as %s (duration=%ds)\n", host, port,
         user, duration);

  /* Create FreeRDP instance */
  freerdp *instance = freerdp_new();
  if (!instance) {
    printf("[rdp_test] ERROR: freerdp_new() failed\n");
    return 1;
  }

  instance->PreConnect = cb_pre_connect;
  instance->PostConnect = cb_post_connect;
  instance->PostDisconnect = cb_post_disconnect;
  instance->VerifyCertificateEx = cb_verify_certificate_ex;

  /* Allocate context */
  if (!freerdp_context_new(instance)) {
    printf("[rdp_test] ERROR: freerdp_context_new() failed\n");
    freerdp_free(instance);
    return 1;
  }

  /* Configure settings */
  rdpSettings *settings = instance->context->settings;
  freerdp_settings_set_string(settings, FreeRDP_ServerHostname, host);
  freerdp_settings_set_uint32(settings, FreeRDP_ServerPort, (UINT32)port);
  freerdp_settings_set_string(settings, FreeRDP_Username, user);
  freerdp_settings_set_string(settings, FreeRDP_Password, pass);
  freerdp_settings_set_bool(settings, FreeRDP_IgnoreCertificate, TRUE);

  /* Desktop size */
  freerdp_settings_set_uint32(settings, FreeRDP_DesktopWidth, 1280);
  freerdp_settings_set_uint32(settings, FreeRDP_DesktopHeight, 720);

  /* Connect */
  printf("[rdp_test] Attempting connection...\n");
  clock_t t_start = clock();

  if (!freerdp_connect(instance)) {
    UINT32 err = freerdp_get_last_error(instance->context);
    printf("[rdp_test] ERROR: freerdp_connect() failed, error=0x%08x\n", err);
    freerdp_context_free(instance);
    freerdp_free(instance);
    return 1;
  }

  double connect_time = (double)(clock() - t_start) / CLOCKS_PER_SEC;
  printf("[rdp_test] CONNECTED in %.2f seconds\n", connect_time);

  /* Event loop */
  time_t end_time = time(NULL) + duration;
  int frame_count = 0;

  while (g_running && time(NULL) < end_time) {
    DWORD nCount = 0;
    HANDLE handles[64];

    nCount = freerdp_get_event_handles(instance->context, handles, 64);
    if (nCount == 0) {
      printf("[rdp_test] ERROR: freerdp_get_event_handles() returned 0\n");
      break;
    }

    DWORD status = WaitForMultipleObjects(nCount, handles, FALSE, 100);
    if (status == WAIT_FAILED) {
      printf("[rdp_test] ERROR: WaitForMultipleObjects failed\n");
      break;
    }

    if (!freerdp_check_event_handles(instance->context)) {
      if (freerdp_get_last_error(instance->context) == FREERDP_ERROR_SUCCESS) {
        printf("[rdp_test] Server closed connection gracefully\n");
      } else {
        printf("[rdp_test] ERROR: check_event_handles failed, error=0x%08x\n",
               freerdp_get_last_error(instance->context));
      }
      break;
    }

    frame_count++;
  }

  printf("[rdp_test] Event loop ended. Frames processed: %d\n", frame_count);

  /* Disconnect */
  printf("[rdp_test] Disconnecting...\n");
  freerdp_disconnect(instance);
  gdi_free(instance);
  freerdp_context_free(instance);
  freerdp_free(instance);

  printf("[rdp_test] Clean shutdown complete.\n");
  return 0;
}
