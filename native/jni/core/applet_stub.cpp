#include <sys/stat.h>

#include <magisk.hpp>

int main(int argc, char *argv[]) {
	umask(0);
	cmdline_logging();
	return APPLET_STUB_MAIN(argc, argv);
}
