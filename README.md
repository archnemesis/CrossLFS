CrossLFS - Cross-Compiled Linux From Scratch
============================================

This project is a set of scripts that serves as a simple proof-of-concept for creating a simple cross-compiled Linux operating system from only package source code archives. It is based off of the work of the Linux From Scratch project, and their (now obsolete) CLFS book.

This project is not meant to serve as an actual operating system used in any kind of real-world environment. Rather, it is meant to serve as an example of what goes in to cross-compiling Linux and all of it's requisite applications.

There is no guarantee that any of the packages are compiled "properly" or in-line with any modern distribution. Many packages have very flexible configuration options that can result in a multitude of permutations of the same binary. These scripts are just examples to illustrate the point, and the binaries produced may not work as expected or intended.

## Getting Started

To get started, you will need to create a configuration file, `build.config`:

```
LFS_ARCH="x86_64"
LFS_PACKAGES=(\
    "zlib" \
    "bzip2" \
    "ncurses" \
    "readline" \
    "attr" \
    "acl" \
    "libcap" \
    "libxcrypt" \
    "shadow" \
    "sed" \
    "psmisc" \
    "expat" \
    "bash" \
    )

```

This configuration will build the listed packages for the x86_64 architecture.

**Warning:** At this time, the only configuration supported is cross-compiling to x86_64. There would be more work required to do ARM cross-compilation, but it is definitely doable inside this framework. Once the configuration file is created, run the following command to bootstrap the target:

```
$ ./build.sh bootstrap
```

This will create the cross-compiler toolchain and install `glibc` to the sysroot and target.

Next, build your selected packages and install them to the target:

```
$ ./build.sh build-all
```

Once that is complete, you can `chroot` into the `target` directory and run any command or program that you installed:

```
$ sudo chroot target /bin/bash
```

To clean up:

```
./build.sh clean
```

Run `./build.sh --help` for a list of options.

