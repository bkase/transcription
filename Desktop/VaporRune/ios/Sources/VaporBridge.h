#include <stdbool.h>
#include <stdint.h>

void *vapor_create(void *layer, float width, float height, float scale,
                   const char *folder, const char *font);
void vapor_destroy(void *host);
void vapor_resize(void *host, float width, float height, float scale);
bool vapor_frame(void *host, double now);
void vapor_touch(void *host, int32_t phase, float x, float y, double now);
void vapor_preferences(void *host, bool reduced_motion);
void vapor_suspend(void *host);
bool vapor_activate(void *host, const char *key);
void vapor_edit(void *host, const char *key, const char *value, bool submit);
char *vapor_nodes(void *host);
void vapor_free_nodes(char *nodes);
uint32_t vapor_color_rgb(const char *name);
