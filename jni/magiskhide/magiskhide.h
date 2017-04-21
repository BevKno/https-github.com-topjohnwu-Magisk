#ifndef MAGISK_HIDE_H
#define MAGISK_HIDE_H

#include <pthread.h>

#define HIDELIST		"/magisk/.core/magiskhide/hidelist"
#define DUMMYPATH		"/dev/magisk/dummy"
#define ENFORCE_FILE 	"/sys/fs/selinux/enforce"
#define POLICY_FILE 	"/sys/fs/selinux/policy"

typedef enum {
	HIDE_ERROR = -1,
	HIDE_SUCCESS = 0,
	HIDE_IS_ENABLED,
	HIDE_NOT_ENABLED,
	HIDE_ITEM_EXIST,
	HIDE_ITEM_NOT_EXIST
} hide_ret;

// Kill process
void kill_proc(int pid);

// Hide daemon
int hide_daemon();

// Process monitor
void proc_monitor();

// Preprocess
void manage_selinux();
void hide_sensitive_props();
void relink_sbin();

// List managements
int add_list(char *proc);
int rm_list(char *proc);
int init_list();
int destroy_list();

extern int sv[2], hide_pid, hideEnabled;
extern struct vector *hide_list;
extern pthread_mutex_t hide_lock;

#endif
