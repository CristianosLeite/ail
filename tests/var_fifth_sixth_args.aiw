# file-backed mmap takes its fd in r8 and its offset in r9, both from variables
sys 319 "\0" as fd                  # memfd_create("", MFD_CLOEXEC)
sys 18 fd "page two\n" 4096         # pwrite at offset 4096
sys 8 fd 4096 0 as off              # lseek returns 4096
sys 9 0 4096 1 2 fd off as p        # mmap(0, 4096, PROT_READ, MAP_PRIVATE, fd, off)
sys 1 1 p 9
