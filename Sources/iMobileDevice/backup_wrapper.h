#ifndef BACKUP_WRAPPER_H
#define BACKUP_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

// Direct call to main() from idevicebackup2.c (renamed to idevicebackup2_main)
// This allows us to call the original main() function directly with argc/argv
int idevicebackup2_main(int argc, char *argv[], progress_callback_t progress_callback, void *callback_userdata);
void idevicebackup2_cancel(void)

#ifdef __cplusplus
}
#endif

#endif /* BACKUP_WRAPPER_H */
