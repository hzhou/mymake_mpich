/* src/include/mpichconf.h.in.  Generated from configure.ac by autoheader.  */

/*
 * Copyright (C) by Argonne National Laboratory
 *     See COPYRIGHT in top-level directory
 */
#ifndef MPICHCONF_H_INCLUDED
#define MPICHCONF_H_INCLUDED


/* Define if building universal (internal helper macro) */
#undef AC_APPLE_UNIVERSAL_BUILD

/* The normal alignment of `bool', in bytes. */
#undef ALIGNOF_BOOL

/* The normal alignment of `char', in bytes. */
#undef ALIGNOF_CHAR

/* The normal alignment of `double', in bytes. */
#undef ALIGNOF_DOUBLE

/* The normal alignment of `float', in bytes. */
#undef ALIGNOF_FLOAT

/* The normal alignment of `int', in bytes. */
#undef ALIGNOF_INT

/* The normal alignment of `int16_t', in bytes. */
#undef ALIGNOF_INT16_T

/* The normal alignment of `int32_t', in bytes. */
#undef ALIGNOF_INT32_T

/* The normal alignment of `int64_t', in bytes. */
#undef ALIGNOF_INT64_T

/* The normal alignment of `int8_t', in bytes. */
#undef ALIGNOF_INT8_T

/* The normal alignment of `long', in bytes. */
#undef ALIGNOF_LONG

/* The normal alignment of `long double', in bytes. */
#undef ALIGNOF_LONG_DOUBLE

/* The normal alignment of `long long', in bytes. */
#undef ALIGNOF_LONG_LONG

/* The normal alignment of `max_align_t', in bytes. */
#undef ALIGNOF_MAX_ALIGN_T

/* The normal alignment of `short', in bytes. */
#undef ALIGNOF_SHORT

/* The normal alignment of `wchar_t', in bytes. */
#undef ALIGNOF_WCHAR_T

/* Define the number of CH3_RANK_BITS */
#undef CH3_RANK_BITS

/* Define the number of rank bits used in UCX */
#undef CH4_UCX_RANKBITS

/* Define the search path for machines files */
#undef DEFAULT_MACHINES_PATH

/* Define the default remote shell program to use */
#undef DEFAULT_REMOTE_SHELL

/* Define to workaround interprocess mutex issue on FreeBSD */
#undef DELAY_SHM_MUTEX_DESTROY

/* Define to enable shared-memory collectives */
#undef ENABLED_SHM_COLLECTIVES

/* Application checkpointing enabled */
#undef ENABLE_CHECKPOINTING

/* Define to skip initializing builtin world comm during MPI_Session_init */
#undef ENABLE_LOCAL_SESSION_INIT

/* Define to disable shared-memory communication */
#undef ENABLE_NO_LOCAL

/* Define to enable PMI1 protocol */
#undef ENABLE_PMI1

/* Define to enable PMI2 protocol */
#undef ENABLE_PMI2

/* Define to enable PMIX protocol */
#undef ENABLE_PMIX

/* Define to 1 to enable getdims-related MPI_T performance variables */
#undef ENABLE_PVAR_DIMS

/* Define to 1 to enable message count transmitted through multiple NICs MPI_T
   performance variables */
#undef ENABLE_PVAR_MULTINIC

/* Define to 1 to enable nemesis-related MPI_T performance variables */
#undef ENABLE_PVAR_NEM

/* Define to 1 to enable message receive queue-related MPI_T performance
   variables */
#undef ENABLE_PVAR_RECVQ

/* Define to 1 to enable rma-related MPI_T performance variables */
#undef ENABLE_PVAR_RMA

/* Define if QMPI enabled */
#undef ENABLE_QMPI

/* "set to enable threadcomm feature" */
#undef ENABLE_THREADCOMM

/* The value of false in Fortran */
#undef F77_FALSE_VALUE

/* Fortran names are lowercase with no trailing underscore */
#undef F77_NAME_LOWER

/* Fortran names are lowercase with two trailing underscores */
#undef F77_NAME_LOWER_2USCORE

/* Fortran names are lowercase with two trailing underscores in stdcall */
#undef F77_NAME_LOWER_2USCORE_STDCALL

/* Fortran names are lowercase with no trailing underscore in stdcall */
#undef F77_NAME_LOWER_STDCALL

/* Fortran names are lowercase with one trailing underscore */
#undef F77_NAME_LOWER_USCORE

/* Fortran names are lowercase with one trailing underscore in stdcall */
#undef F77_NAME_LOWER_USCORE_STDCALL

/* Fortran names preserve the original case */
#undef F77_NAME_MIXED

/* Fortran names preserve the original case in stdcall */
#undef F77_NAME_MIXED_STDCALL

/* Fortran names preserve the original case with one trailing underscore */
#undef F77_NAME_MIXED_USCORE

/* Fortran names preserve the original case with one trailing underscore in
   stdcall */
#undef F77_NAME_MIXED_USCORE_STDCALL

/* Fortran names are uppercase */
#undef F77_NAME_UPPER

/* Fortran names are uppercase in stdcall */
#undef F77_NAME_UPPER_STDCALL

/* The value of true in Fortran */
#undef F77_TRUE_VALUE

/* Define if we know the value of Fortran true and false */
#undef F77_TRUE_VALUE_SET

/* Define FALSE */
#undef FALSE

/* Directory to use in namepub */
#undef FILE_NAMEPUB_BASEDIR

/* Define if PMIx_Load_topology is available */
#undef HAS_PMIX_LOAD_TOPOLOGY

/* Define if addresses are a different size than Fortran integers */
#undef HAVE_AINT_DIFFERENT_THAN_FINT

/* Define if addresses are larger than Fortran integers */
#undef HAVE_AINT_LARGER_THAN_FINT

/* Define to 1 if you have the `alarm' function. */
#undef HAVE_ALARM

/* Define if int32_t works with any alignment */
#undef HAVE_ANY_INT32_T_ALIGNMENT

/* Define if int64_t works with any alignment */
#undef HAVE_ANY_INT64_T_ALIGNMENT

/* Define to 1 if you have the <arpa/inet.h> header file. */
#undef HAVE_ARPA_INET_H

/* Define to 1 if you have the <assert.h> header file. */
#undef HAVE_ASSERT_H

/* Define to 1 if you have the `bindprocessor' function. */
#undef HAVE_BINDPROCESSOR

/* Define to 1 if the compiler supports __builtin_expect. */
#undef HAVE_BUILTIN_EXPECT

/* Define if C11 _Static_assert is supported. */
#undef HAVE_C11__STATIC_ASSERT

/* Define to 1 if you have the `CFUUIDCreate' function. */
#undef HAVE_CFUUIDCREATE

/* Define if debugger support is included for CH4 */
#undef HAVE_CH4_DEBUGGER_SUPPORT

/* OFI netmod is built */
#undef HAVE_CH4_NETMOD_OFI

/* UCX netmod is built */
#undef HAVE_CH4_NETMOD_UCX

/* IQUEUE submodule is built */
#undef HAVE_CH4_SHM_EAGER_IQUEUE

/* STUB submodule is built */
#undef HAVE_CH4_SHM_EAGER_STUB

/* Define to 1 if you have the <complex.h> header file. */
#undef HAVE_COMPLEX_H

/* Define if CPU_SET and CPU_ZERO defined */
#undef HAVE_CPU_SET_MACROS

/* Define if cpu_set_t is defined in sched.h */
#undef HAVE_CPU_SET_T

/* Define to 1 if you have the <ctype.h> header file. */
#undef HAVE_CTYPE_H

/* Define if C++ is supported */
#undef HAVE_CXX_BINDING

/* Define if C++ supports bool types */
#undef HAVE_CXX_BOOL

/* Define if C++ supports complex types */
#undef HAVE_CXX_COMPLEX

/* define if the compiler supports exceptions */
#undef HAVE_CXX_EXCEPTIONS

/* Define if C++ supports long double complex */
#undef HAVE_CXX_LONG_DOUBLE_COMPLEX

/* Define if multiple __attribute__((alias)) are supported */
#undef HAVE_C_MULTI_ATTR_ALIAS

/* Define if debugger support is included */
#undef HAVE_DEBUGGER_SUPPORT

/* Define to 1 if you have the declaration of `strerror_r', and to 0 if you
   don't. */
#undef HAVE_DECL_STRERROR_R

/* Define to 1 if you have the <dlfcn.h> header file. */
#undef HAVE_DLFCN_H

/* Define to 1 if the system has the type `double _Complex'. */
#undef HAVE_DOUBLE__COMPLEX

/* Define to 1 if you have the <endian.h> header file. */
#undef HAVE_ENDIAN_H

/* Define to 1 if you have the <errno.h> header file. */
#undef HAVE_ERRNO_H

/* Define to enable error checking */
#undef HAVE_ERROR_CHECKING

/* Define to enable extended context id bit space */
#undef HAVE_EXTENDED_CONTEXT_BITS

/* Define if environ extern is available */
#undef HAVE_EXTERN_ENVIRON

/* Define to 1 if we have Fortran 2008 binding */
#undef HAVE_F08_BINDING

/* Define to 1 if you have the <fcntl.h> header file. */
#undef HAVE_FCNTL_H

/* Define if Fortran integer are the same size as C ints */
#undef HAVE_FINT_IS_INT

/* Define if __float128 is supported */
#undef HAVE_FLOAT128

/* Define if _Float16 is supported */
#undef HAVE_FLOAT16

/* Define to 1 if the system has the type `float _Complex'. */
#undef HAVE_FLOAT__COMPLEX

/* Define if Fortran is supported */
#undef HAVE_FORTRAN_BINDING

/* Define if GNU __attribute__ is supported */
#undef HAVE_GCC_ATTRIBUTE

/* Define to 1 if you have the `gethostname' function. */
#undef HAVE_GETHOSTNAME

/* Define to 1 if you have the `getsid' function. */
#undef HAVE_GETSID

/* Define if building hcoll */
#undef HAVE_HCOLL

/* Define if hwloc is available */
#undef HAVE_HWLOC

/* Define to 1 if you have the `inet_pton' function. */
#undef HAVE_INET_PTON

/* Define if int16_t is supported by the C compiler */
#undef HAVE_INT16_T

/* Define if int32_t is supported by the C compiler */
#undef HAVE_INT32_T

/* Define if int64_t is supported by the C compiler */
#undef HAVE_INT64_T

/* Define if int8_t is supported by the C compiler */
#undef HAVE_INT8_T

/* Define to 1 if you have the <inttypes.h> header file. */
#undef HAVE_INTTYPES_H

/* Define if struct iovec defined in sys/uio.h */
#undef HAVE_IOVEC_DEFINITION

/* Define to 1 if you have the `isatty' function. */
#undef HAVE_ISATTY

/* Define to 1 if you have the `cr' library (-lcr). */
#undef HAVE_LIBCR

/* Define to 1 if you have the `fabric' library (-lfabric). */
#undef HAVE_LIBFABRIC

/* Define if libfabric library has nic field in fi_info struct */
#undef HAVE_LIBFABRIC_NIC

/* Define to 1 if you have the `pmi' library (-lpmi). */
#undef HAVE_LIBPMI

/* Define to 1 if you have the `ucp' library (-lucp). */
#undef HAVE_LIBUCP

/* Define to 1 if you have the <limits.h> header file. */
#undef HAVE_LIMITS_H

/* Define if long double is supported */
#undef HAVE_LONG_DOUBLE

/* Define to 1 if the system has the type `long double _Complex'. */
#undef HAVE_LONG_DOUBLE__COMPLEX

/* Define if long long allowed */
#undef HAVE_LONG_LONG

/* Define if long long is supported */
#undef HAVE_LONG_LONG_INT

/* Define if C99-style variable argument list macro functionality */
#undef HAVE_MACRO_VA_ARGS

/* Define to 1 if you have the <minix/config.h> header file. */
#undef HAVE_MINIX_CONFIG_H

/* Define so that we can test whether the mpichconf.h file has been included
   */
#undef HAVE_MPICHCONF

/* Define if MPI_T Events are enabled */
#undef HAVE_MPIT_EVENTS

/* Define if the Fortran init code for MPI works from C programs without
   special libraries */
#undef HAVE_MPI_F_INIT_WORKS_WITH_C

/* Define if multiple weak symbols may be defined */
#undef HAVE_MULTIPLE_PRAGMA_WEAK

/* Define if a name publishing service is available */
#undef HAVE_NAMEPUB_SERVICE

/* define if the compiler implements namespaces */
#undef HAVE_NAMESPACES

/* define if the compiler implements namespace std */
#undef HAVE_NAMESPACE_STD

/* Define to 1 if you have the <netdb.h> header file. */
#undef HAVE_NETDB_H

/* Define if netinet/in.h exists */
#undef HAVE_NETINET_IN_H

/* Define to 1 if you have the <netinet/tcp.h> header file. */
#undef HAVE_NETINET_TCP_H

/* Define if netloc is available */
#undef HAVE_NETLOC

/* Define to 1 if you have the <net/if.h> header file. */
#undef HAVE_NET_IF_H

/* Define if the Fortran types are not available in C */
#undef HAVE_NO_FORTRAN_MPI_TYPES_IN_C

/* Define if the OSX thread affinity policy macros defined */
#undef HAVE_OSX_THREAD_AFFINITY

/* Define if PMI2_Set_threaded exist */
#undef HAVE_PMI2_SET_THREADED

/* Define to 1 if you have the <poll.h> header file. */
#undef HAVE_POLL_H

/* Cray style weak pragma */
#undef HAVE_PRAGMA_CRI_DUP

/* HP style weak pragma */
#undef HAVE_PRAGMA_HP_SEC_DEF

/* Supports weak pragma */
#undef HAVE_PRAGMA_WEAK

/* Define to 1 if you have the `process_vm_readv' function. */
#undef HAVE_PROCESS_VM_READV

/* Define to 1 if you have the `ptrace' function. */
#undef HAVE_PTRACE

/* Define if ptrace parameters available */
#undef HAVE_PTRACE_CONT

/* Define to 1 if you have the `putenv' function. */
#undef HAVE_PUTENV

/* Define to 1 if you have the `qsort' function. */
#undef HAVE_QSORT

/* Define to 1 if you have the <random.h> header file. */
#undef HAVE_RANDOM_H

/* Define to 1 if you have the `random_r' function. */
#undef HAVE_RANDOM_R

/* Define if ROMIO is enabled */
#undef HAVE_ROMIO

/* Define to 1 if you have the `sched_getaffinity' function. */
#undef HAVE_SCHED_GETAFFINITY

/* Define to 1 if you have the <sched.h> header file. */
#undef HAVE_SCHED_H

/* Define to 1 if you have the `sched_setaffinity' function. */
#undef HAVE_SCHED_SETAFFINITY

/* Define to 1 if you have the `select' function. */
#undef HAVE_SELECT

/* Define to 1 if you have the `setitimer' function. */
#undef HAVE_SETITIMER

/* Define to 1 if you have the `setsid' function. */
#undef HAVE_SETSID

/* Define to 1 if you have the `sigaction' function. */
#undef HAVE_SIGACTION

/* Define to 1 if you have the `signal' function. */
#undef HAVE_SIGNAL

/* Define to 1 if you have the <signal.h> header file. */
#undef HAVE_SIGNAL_H

/* Define to 1 if you have the `sigset' function. */
#undef HAVE_SIGSET

/* Define if socklen_t is available */
#undef HAVE_SOCKLEN_T

/* Define to 1 if you have the <stdarg.h> header file. */
#undef HAVE_STDARG_H

/* Define to 1 if you have the <stdbool.h> header file. */
#undef HAVE_STDBOOL_H

/* Define to 1 if you have the <stddef.h> header file. */
#undef HAVE_STDDEF_H

/* Define to 1 if you have the <stdint.h> header file. */
#undef HAVE_STDINT_H

/* Define to 1 if you have the <stdio.h> header file. */
#undef HAVE_STDIO_H

/* Define to 1 if you have the <stdlib.h> header file. */
#undef HAVE_STDLIB_H

/* Define to 1 if you have the `strdup' function. */
#undef HAVE_STRDUP

/* Define to 1 if you have the `strerror' function. */
#undef HAVE_STRERROR

/* Define if you have `strerror_r'. */
#undef HAVE_STRERROR_R

/* Define to 1 if you have the <strings.h> header file. */
#undef HAVE_STRINGS_H

/* Define to 1 if you have the <string.h> header file. */
#undef HAVE_STRING_H

/* Define to 1 if you have the `strncasecmp' function. */
#undef HAVE_STRNCASECMP

/* Define to 1 if you have the `strsignal' function. */
#undef HAVE_STRSIGNAL

/* Define to 1 if the system has the type `struct random_data'. */
#undef HAVE_STRUCT_RANDOM_DATA

/* Define if sys/bitypes.h exists */
#undef HAVE_SYS_BITYPES_H

/* Define to 1 if you have the <sys/ioctl.h> header file. */
#undef HAVE_SYS_IOCTL_H

/* Define to 1 if you have the <sys/ipc.h> header file. */
#undef HAVE_SYS_IPC_H

/* Define to 1 if you have the <sys/mman.h> header file. */
#undef HAVE_SYS_MMAN_H

/* Define to 1 if you have the <sys/param.h> header file. */
#undef HAVE_SYS_PARAM_H

/* Define to 1 if you have the <sys/poll.h> header file. */
#undef HAVE_SYS_POLL_H

/* Define to 1 if you have the <sys/ptrace.h> header file. */
#undef HAVE_SYS_PTRACE_H

/* Define to 1 if you have the <sys/select.h> header file. */
#undef HAVE_SYS_SELECT_H

/* Define to 1 if you have the <sys/shm.h> header file. */
#undef HAVE_SYS_SHM_H

/* Define to 1 if you have the <sys/socket.h> header file. */
#undef HAVE_SYS_SOCKET_H

/* Define to 1 if you have the <sys/sockio.h> header file. */
#undef HAVE_SYS_SOCKIO_H

/* Define to 1 if you have the <sys/stat.h> header file. */
#undef HAVE_SYS_STAT_H

/* Define to 1 if you have the <sys/time.h> header file. */
#undef HAVE_SYS_TIME_H

/* Define to 1 if you have the <sys/types.h> header file. */
#undef HAVE_SYS_TYPES_H

/* Define to 1 if you have the <sys/uio.h> header file. */
#undef HAVE_SYS_UIO_H

/* Define to enable tag error bits */
#undef HAVE_TAG_ERROR_BITS

/* Define to 1 if you have the `thread_policy_set' function. */
#undef HAVE_THREAD_POLICY_SET

/* Define to 1 if you have the `time' function. */
#undef HAVE_TIME

/* Define to 1 if you have the <time.h> header file. */
#undef HAVE_TIME_H

/* Define if uint16_t is supported by the C compiler */
#undef HAVE_UINT16_T

/* Define if uint32_t is supported by the C compiler */
#undef HAVE_UINT32_T

/* Define if uint64_t is supported by the C compiler */
#undef HAVE_UINT64_T

/* Define if uint8_t is supported by the C compiler */
#undef HAVE_UINT8_T

/* Define to 1 if you have the <unistd.h> header file. */
#undef HAVE_UNISTD_H

/* Define to 1 if you have the `unsetenv' function. */
#undef HAVE_UNSETENV

/* Define to 1 if you have the `usleep' function. */
#undef HAVE_USLEEP

/* Define to 1 if you have the `uuid_generate' function. */
#undef HAVE_UUID_GENERATE

/* Define to 1 if you have the <uuid/uuid.h> header file. */
#undef HAVE_UUID_UUID_H

/* Whether C compiler supports symbol visibility or not */
#undef HAVE_VISIBILITY

/* Define to 1 if you have the `vsnprintf' function. */
#undef HAVE_VSNPRINTF

/* Define to 1 if you have the `vsprintf' function. */
#undef HAVE_VSPRINTF

/* Define to 1 if you have the <wait.h> header file. */
#undef HAVE_WAIT_H

/* Define to 1 if you have the <wchar.h> header file. */
#undef HAVE_WCHAR_H

/* Attribute style weak pragma */
#undef HAVE_WEAK_ATTRIBUTE

/* Define to 1 if the system has the type `_Bool'. */
#undef HAVE__BOOL

/* Define to the sub-directory where libtool stores uninstalled libraries. */
#undef LT_OBJDIR

/* Controls byte alignment of structures (for aligning allocated structures)
   */
#undef MAX_ALIGNMENT

/* Define if PMI2_KEYVAL_T is missing */
#undef MISSING_PMI2_KEYVAL_T

/* Datatype engine */
#undef MPICH_DATATYPE_ENGINE

/* Define to enable checking of handles still allocated at MPI_Finalize */
#undef MPICH_DEBUG_HANDLEALLOC

/* Define to enable handle checking */
#undef MPICH_DEBUG_HANDLES

/* Define if each function exit should confirm memory arena correctness */
#undef MPICH_DEBUG_MEMARENA

/* Define to enable preinitialization of memory used by structures and unions
   */
#undef MPICH_DEBUG_MEMINIT

/* Define to enable mutex debugging */
#undef MPICH_DEBUG_MUTEX

/* Define to enable mutex debugging */
#undef MPICH_DEBUG_PROGRESS

/* Define as the name of the debugger support library */
#undef MPICH_INFODLL_LOC

/* MPICH is configured to require thread safety */
#undef MPICH_IS_THREADED

/* Method used to implement atomic updates and access */
#undef MPICH_THREAD_GRANULARITY

/* Level of thread support selected at compile time */
#undef MPICH_THREAD_LEVEL

/* Method used to implement refcount updates */
#undef MPICH_THREAD_REFCOUNT

/* define to disable reference counting predefined objects like MPI_COMM_WORLD
   */
#undef MPICH_THREAD_SUPPRESS_PREDEFINED_REFCOUNTS

/* CH4 Directly transfers data through the chosen netmode */
#undef MPIDI_CH4_DIRECT_NETMOD

/* Number of VCIs configured in CH4 */
#undef MPIDI_CH4_MAX_VCIS

/* Define to use bgq capability set */
#undef MPIDI_CH4_OFI_USE_SET_BGQ

/* Define to use cxi capability set */
#undef MPIDI_CH4_OFI_USE_SET_CXI

/* Define to use gni capability set */
#undef MPIDI_CH4_OFI_USE_SET_GNI

/* Define to use PSM2 capability set */
#undef MPIDI_CH4_OFI_USE_SET_PSM2

/* Define to use PSM3 capability set */
#undef MPIDI_CH4_OFI_USE_SET_PSM3

/* Define to use runtime capability set */
#undef MPIDI_CH4_OFI_USE_SET_RUNTIME

/* Define to use sockets capability set */
#undef MPIDI_CH4_OFI_USE_SET_SOCKETS

/* Define to use verbs;ofi_rxm capability set */
#undef MPIDI_CH4_OFI_USE_SET_VERBS_RXM

/* Enable CMA IPC in CH4 */
#undef MPIDI_CH4_SHM_ENABLE_CMA

/* Define if GPU IPC submodule is enabled */
#undef MPIDI_CH4_SHM_ENABLE_GPU

/* Enable XPMEM shared memory submodule in CH4 */
#undef MPIDI_CH4_SHM_ENABLE_XPMEM

/* Silently disable XPMEM, if it fails at runtime */
#undef MPIDI_CH4_SHM_XPMEM_ALLOW_SILENT_FALLBACK

/* Define to enable direct multi-threading model */
#undef MPIDI_CH4_USE_MT_DIRECT

/* Define to enable lockless multi-threading model */
#undef MPIDI_CH4_USE_MT_LOCKLESS

/* Define to enable runtime multi-threading model */
#undef MPIDI_CH4_USE_MT_RUNTIME

/* Method used to select vci */
#undef MPIDI_CH4_VCI_METHOD

/* Enables AM-only communication */
#undef MPIDI_ENABLE_AM_ONLY

/* CH4/OFI should use domain for vci contexts */
#undef MPIDI_OFI_VNI_USE_DOMAIN

/* Define to turn on the inlining optimizations in Nemesis code */
#undef MPID_NEM_INLINE

/* Method for local large message transfers. */
#undef MPID_NEM_LOCAL_LMT_IMPL

/* Define if a port may be used to communicate with the processes */
#undef MPIEXEC_ALLOW_PORT

/* Internal type for MPI_2DOUBLE_PRECISION */
#undef MPIR_2DOUBLE_PRECISION_INTERNAL

/* Internal type for MPI_2INTEGER */
#undef MPIR_2INTEGER_INTERNAL

/* Internal type for MPI_2INT */
#undef MPIR_2INT_INTERNAL

/* Internal type for MPI_2REAL */
#undef MPIR_2REAL_INTERNAL

/* Internal type for MPI_AINT_DATATYPE */
#undef MPIR_AINT_INTERNAL

/* limits.h _MAX constant for MPI_Aint */
#undef MPIR_AINT_MAX

/* limits.h _MIN constant for MPI_Aint */
#undef MPIR_AINT_MIN

/* The C type for MPIR_ALT_COMPLEX128 */
#undef MPIR_ALT_COMPLEX128_CTYPE

/* The C type for MPIR_ALT_COMPLEX96 */
#undef MPIR_ALT_COMPLEX96_CTYPE

/* The C type for MPIR_ALT_FLOAT128 */
#undef MPIR_ALT_FLOAT128_CTYPE

/* The C type for MPIR_ALT_FLOAT96 */
#undef MPIR_ALT_FLOAT96_CTYPE

/* Internal type for MPI_BYTE */
#undef MPIR_BYTE_INTERNAL

/* Internal type for MPI_CHARACTER */
#undef MPIR_CHARACTER_INTERNAL

/* Internal type for MPI_CHAR */
#undef MPIR_CHAR_INTERNAL

/* The C type for MPIR_COMPLEX128 */
#undef MPIR_COMPLEX128_CTYPE

/* The C type for MPIR_COMPLEX16 */
#undef MPIR_COMPLEX16_CTYPE

/* Internal type for MPI_COMPLEX16 */
#undef MPIR_COMPLEX16_INTERNAL

/* The C type for MPIR_COMPLEX32 */
#undef MPIR_COMPLEX32_CTYPE

/* Internal type for MPI_COMPLEX32 */
#undef MPIR_COMPLEX32_INTERNAL

/* Internal type for MPI_COMPLEX4 */
#undef MPIR_COMPLEX4_INTERNAL

/* The C type for MPIR_COMPLEX64 */
#undef MPIR_COMPLEX64_CTYPE

/* Internal type for MPI_COMPLEX8 */
#undef MPIR_COMPLEX8_INTERNAL

/* Internal type for MPI_COMPLEX */
#undef MPIR_COMPLEX_INTERNAL

/* Internal type for MPI_COUNT_DATATYPE */
#undef MPIR_COUNT_INTERNAL

/* limits.h _MAX constant for MPI_Count */
#undef MPIR_COUNT_MAX

/* a C type used to compute C++ bool reductions */
#undef MPIR_CXX_BOOL_CTYPE

/* Internal type for MPI_CXX_BOOL */
#undef MPIR_CXX_BOOL_INTERNAL

/* Internal type for MPI_CXX_DOUBLE_COMPLEX */
#undef MPIR_CXX_DOUBLE_COMPLEX_INTERNAL

/* Internal type for MPI_CXX_FLOAT_COMPLEX */
#undef MPIR_CXX_FLOAT_COMPLEX_INTERNAL

/* Internal type for MPI_CXX_LONG_DOUBLE_COMPLEX */
#undef MPIR_CXX_LONG_DOUBLE_COMPLEX_INTERNAL

/* Internal type for MPI_C_BOOL */
#undef MPIR_C_BOOL_INTERNAL

/* Internal type for MPI_C_COMPLEX */
#undef MPIR_C_COMPLEX_INTERNAL

/* Internal type for MPI_C_DOUBLE_COMPLEX */
#undef MPIR_C_DOUBLE_COMPLEX_INTERNAL

/* Internal type for MPIX_C_FLOAT16 */
#undef MPIR_C_FLOAT16_INTERNAL

/* Internal type for MPI_C_LONG_DOUBLE_COMPLEX */
#undef MPIR_C_LONG_DOUBLE_COMPLEX_INTERNAL

/* Internal type for MPI_DOUBLE_COMPLEX */
#undef MPIR_DOUBLE_COMPLEX_INTERNAL

/* Internal type for MPI_DOUBLE */
#undef MPIR_DOUBLE_INTERNAL

/* Internal type for MPI_DOUBLE_PRECISION */
#undef MPIR_DOUBLE_PRECISION_INTERNAL

/* The C type for MPIR_FLOAT128 */
#undef MPIR_FLOAT128_CTYPE

/* The C type for MPIR_FLOAT16 */
#undef MPIR_FLOAT16_CTYPE

/* The C type for MPIR_FLOAT32 */
#undef MPIR_FLOAT32_CTYPE

/* The C type for MPIR_FLOAT64 */
#undef MPIR_FLOAT64_CTYPE

/* The C type for MPIR_FLOAT8 */
#undef MPIR_FLOAT8_CTYPE

/* Internal type for MPI_FLOAT */
#undef MPIR_FLOAT_INTERNAL

/* The C type for MPIR_INT128 */
#undef MPIR_INT128_CTYPE

/* The C type for MPIR_INT16 */
#undef MPIR_INT16_CTYPE

/* Internal type for MPI_INT16_T */
#undef MPIR_INT16_T_INTERNAL

/* The C type for MPIR_INT32 */
#undef MPIR_INT32_CTYPE

/* Internal type for MPI_INT32_T */
#undef MPIR_INT32_T_INTERNAL

/* The C type for MPIR_INT64 */
#undef MPIR_INT64_CTYPE

/* Internal type for MPI_INT64_T */
#undef MPIR_INT64_T_INTERNAL

/* The C type for MPIR_INT8 */
#undef MPIR_INT8_CTYPE

/* Internal type for MPI_INT8_T */
#undef MPIR_INT8_T_INTERNAL

/* Internal type for MPI_INTEGER16 */
#undef MPIR_INTEGER16_INTERNAL

/* Internal type for MPI_INTEGER1 */
#undef MPIR_INTEGER1_INTERNAL

/* Internal type for MPI_INTEGER2 */
#undef MPIR_INTEGER2_INTERNAL

/* Internal type for MPI_INTEGER4 */
#undef MPIR_INTEGER4_INTERNAL

/* Internal type for MPI_INTEGER8 */
#undef MPIR_INTEGER8_INTERNAL

/* Internal type for MPI_INTEGER */
#undef MPIR_INTEGER_INTERNAL

/* Internal type for MPI_INT */
#undef MPIR_INT_INTERNAL

/* Internal type for MPI_LB */
#undef MPIR_LB_INTERNAL

/* Internal type for MPI_LOGICAL */
#undef MPIR_LOGICAL_INTERNAL

/* Internal type for MPI_LONG_DOUBLE */
#undef MPIR_LONG_DOUBLE_INTERNAL

/* Internal type for MPI_LONG */
#undef MPIR_LONG_INTERNAL

/* Internal type for MPI_LONGLONG_INT */
#undef MPIR_LONG_LONG_INT_INTERNAL

/* Internal type for MPI_OFFSET_DATATYPE */
#undef MPIR_OFFSET_INTERNAL

/* limits.h _MAX constant for MPI_Offset */
#undef MPIR_OFFSET_MAX

/* Internal type for MPI_PACKED */
#undef MPIR_PACKED_INTERNAL

/* Internal type for MPI_REAL16 */
#undef MPIR_REAL16_INTERNAL

/* Internal type for MPI_REAL2 */
#undef MPIR_REAL2_INTERNAL

/* Internal type for MPI_REAL4 */
#undef MPIR_REAL4_INTERNAL

/* Internal type for MPI_REAL8 */
#undef MPIR_REAL8_INTERNAL

/* Internal type for MPI_REAL */
#undef MPIR_REAL_INTERNAL

/* Internal type for MPI_SHORT */
#undef MPIR_SHORT_INTERNAL

/* Internal type for MPI_SIGNED_CHAR */
#undef MPIR_SIGNED_CHAR_INTERNAL

/* Internal type for MPI_UB */
#undef MPIR_UB_INTERNAL

/* The C type for MPIR_UINT128 */
#undef MPIR_UINT128_CTYPE

/* The C type for MPIR_UINT16 */
#undef MPIR_UINT16_CTYPE

/* Internal type for MPI_UINT16_T */
#undef MPIR_UINT16_T_INTERNAL

/* The C type for MPIR_UINT32 */
#undef MPIR_UINT32_CTYPE

/* Internal type for MPI_UINT32_T */
#undef MPIR_UINT32_T_INTERNAL

/* The C type for MPIR_UINT64 */
#undef MPIR_UINT64_CTYPE

/* Internal type for MPI_UINT64_T */
#undef MPIR_UINT64_T_INTERNAL

/* The C type for MPIR_UINT8 */
#undef MPIR_UINT8_CTYPE

/* Internal type for MPI_UINT8_T */
#undef MPIR_UINT8_T_INTERNAL

/* Internal type for MPI_UNSIGNED_CHAR */
#undef MPIR_UNSIGNED_CHAR_INTERNAL

/* Internal type for MPI_UNSIGNED */
#undef MPIR_UNSIGNED_INTERNAL

/* Internal type for MPI_UNSIGNED_LONG */
#undef MPIR_UNSIGNED_LONG_INTERNAL

/* Internal type for MPI_UNSIGNED_LONG_LONG */
#undef MPIR_UNSIGNED_LONG_LONG_INTERNAL

/* Internal type for MPI_UNSIGNED_SHORT */
#undef MPIR_UNSIGNED_SHORT_INTERNAL

/* MPIR_Ucount is an unsigned MPI_Count-sized integer */
#undef MPIR_Ucount

/* Internal type for MPI_WCHAR */
#undef MPIR_WCHAR_INTERNAL

/* Define to enable timing mutexes */
#undef MPIU_MUTEX_WAIT_TIME

/* Define if /bin must be in path */
#undef NEEDS_BIN_IN_PATH

/* Define if environ decl needed */
#undef NEEDS_ENVIRON_DECL

/* Define if gethostname needs a declaration */
#undef NEEDS_GETHOSTNAME_DECL

/* Define if getsid needs a declaration */
#undef NEEDS_GETSID_DECL

/* Define if _POSIX_SOURCE needed to get sigaction */
#undef NEEDS_POSIX_FOR_SIGACTION

/* Define if putenv needs a declaration */
#undef NEEDS_PUTENV_DECL

/* Define if strdup needs a declaration */
#undef NEEDS_STRDUP_DECL

/* Define if strerror_r needs a declaration */
#undef NEEDS_STRERROR_R_DECL

/* Define if strict alignment memory access is required */
#undef NEEDS_STRICT_ALIGNMENT

/* Define if strsignal needs a declaration */
#undef NEEDS_STRSIGNAL_DECL

/* Define if vsnprintf needs a declaration */
#undef NEEDS_VSNPRINTF_DECL

/* Define if PMIX_INFO_LOAD macro is needed */
#undef NEED_PMIX_INFO_LOAD

/* The PMI library does not have PMI_Spawn_multiple. */
#undef NO_PMI_SPAWN_MULTIPLE

/* Name of package */
#undef PACKAGE

/* Define to the address where bug reports for this package should be sent. */
#undef PACKAGE_BUGREPORT

/* Define to the full name of this package. */
#undef PACKAGE_NAME

/* Define to the full name and version of this package. */
#undef PACKAGE_STRING

/* Define to the one symbol short name of this package. */
#undef PACKAGE_TARNAME

/* Define to the home page for this package. */
#undef PACKAGE_URL

/* Define to the version of this package. */
#undef PACKAGE_VERSION

/* define if PMI is supplied from 3rd party (thus we should limit usage of
   MPICH extensions) */
#undef PMI_FROM_3RD_PARTY

/* Define to turn on the prefetching optimization in Nemesis code */
#undef PREFETCH_CELL

/* The size of `bool', as computed by sizeof. */
#undef SIZEOF_BOOL

/* The size of `char', as computed by sizeof. */
#undef SIZEOF_CHAR

/* The size of `Complex', as computed by sizeof. */
#undef SIZEOF_COMPLEX

/* The size of `double', as computed by sizeof. */
#undef SIZEOF_DOUBLE

/* The size of `DoubleComplex', as computed by sizeof. */
#undef SIZEOF_DOUBLECOMPLEX

/* The size of `double_int', as computed by sizeof. */
#undef SIZEOF_DOUBLE_INT

/* The size of `double _Complex', as computed by sizeof. */
#undef SIZEOF_DOUBLE__COMPLEX

/* Define size of PAC_TYPE_NAME */
#undef SIZEOF_F77_DOUBLE_PRECISION

/* Define size of PAC_TYPE_NAME */
#undef SIZEOF_F77_INTEGER

/* Define size of PAC_TYPE_NAME */
#undef SIZEOF_F77_LOGICAL

/* Define size of PAC_TYPE_NAME */
#undef SIZEOF_F77_REAL

/* The size of `float', as computed by sizeof. */
#undef SIZEOF_FLOAT

/* The size of `float_int', as computed by sizeof. */
#undef SIZEOF_FLOAT_INT

/* The size of `float _Complex', as computed by sizeof. */
#undef SIZEOF_FLOAT__COMPLEX

/* The size of `int', as computed by sizeof. */
#undef SIZEOF_INT

/* The size of `int16_t', as computed by sizeof. */
#undef SIZEOF_INT16_T

/* The size of `int32_t', as computed by sizeof. */
#undef SIZEOF_INT32_T

/* The size of `int64_t', as computed by sizeof. */
#undef SIZEOF_INT64_T

/* The size of `int8_t', as computed by sizeof. */
#undef SIZEOF_INT8_T

/* The size of `long', as computed by sizeof. */
#undef SIZEOF_LONG

/* The size of `LongDoubleComplex', as computed by sizeof. */
#undef SIZEOF_LONGDOUBLECOMPLEX

/* The size of `long double', as computed by sizeof. */
#undef SIZEOF_LONG_DOUBLE

/* The size of `long_double_int', as computed by sizeof. */
#undef SIZEOF_LONG_DOUBLE_INT

/* The size of `long double _Complex', as computed by sizeof. */
#undef SIZEOF_LONG_DOUBLE__COMPLEX

/* The size of `long_int', as computed by sizeof. */
#undef SIZEOF_LONG_INT

/* The size of `long long', as computed by sizeof. */
#undef SIZEOF_LONG_LONG

/* The size of `MPII_Bsend_data_t', as computed by sizeof. */
#undef SIZEOF_MPII_BSEND_DATA_T

/* The size of `short', as computed by sizeof. */
#undef SIZEOF_SHORT

/* The size of `short_int', as computed by sizeof. */
#undef SIZEOF_SHORT_INT

/* The size of `two_int', as computed by sizeof. */
#undef SIZEOF_TWO_INT

/* The size of `uint16_t', as computed by sizeof. */
#undef SIZEOF_UINT16_T

/* The size of `uint32_t', as computed by sizeof. */
#undef SIZEOF_UINT32_T

/* The size of `uint64_t', as computed by sizeof. */
#undef SIZEOF_UINT64_T

/* The size of `uint8_t', as computed by sizeof. */
#undef SIZEOF_UINT8_T

/* The size of `unsigned char', as computed by sizeof. */
#undef SIZEOF_UNSIGNED_CHAR

/* The size of `unsigned int', as computed by sizeof. */
#undef SIZEOF_UNSIGNED_INT

/* The size of `unsigned long', as computed by sizeof. */
#undef SIZEOF_UNSIGNED_LONG

/* The size of `unsigned long long', as computed by sizeof. */
#undef SIZEOF_UNSIGNED_LONG_LONG

/* The size of `unsigned short', as computed by sizeof. */
#undef SIZEOF_UNSIGNED_SHORT

/* The size of `void *', as computed by sizeof. */
#undef SIZEOF_VOID_P

/* The size of `wchar_t', as computed by sizeof. */
#undef SIZEOF_WCHAR_T

/* The size of `_Bool', as computed by sizeof. */
#undef SIZEOF__BOOL

/* The size of `_Float16', as computed by sizeof. */
#undef SIZEOF__FLOAT16

/* The size of `__float128', as computed by sizeof. */
#undef SIZEOF___FLOAT128

/* Define calling convention */
#undef STDCALL

/* Define to 1 if all of the C90 standard headers exist (not just the ones
   required in a freestanding environment). This macro is provided for
   backward compatibility; new code need not use it. */
#undef STDC_HEADERS

/* Define to 1 if strerror_r returns char *. */
#undef STRERROR_R_CHAR_P

/* Define TRUE */
#undef TRUE

/* Define if MPI_Aint should be used instead of void * for storing attribute
   values */
#undef USE_AINT_FOR_ATTRVAL

/* define to use global config file */
#undef USE_CONFIGFILE

/* Define if performing coverage tests */
#undef USE_COVERAGE

/* Define to use the fastboxes in Nemesis code */
#undef USE_FASTBOX

/* Define if file should be used for name publisher */
#undef USE_FILE_FOR_NAMEPUB

/* Define if the length of a CHARACTER*(*) string in Fortran should be passed
   as size_t instead of int */
#undef USE_FORT_STR_LEN_SIZET

/* Define to enable memory tracing */
#undef USE_MEMORY_TRACING

/* Define if mpiexec should create a new process group session */
#undef USE_NEW_SESSION

/* Define if using Slurm PMI 1 */
#undef USE_PMI1_SLURM

/* Define if using Slurm PMI 2 */
#undef USE_PMI2_SLURM

/* Define if sigaction should be used to set signals */
#undef USE_SIGACTION

/* Define if signal should be used to set signals */
#undef USE_SIGNAL

/* Define it the socket verify macros should be enabled */
#undef USE_SOCK_VERIFY

/* Define if we can use a symmetric heap */
#undef USE_SYM_HEAP

/* Enable extensions on AIX 3, Interix.  */
#ifndef _ALL_SOURCE
# undef _ALL_SOURCE
#endif
/* Enable general extensions on macOS.  */
#ifndef _DARWIN_C_SOURCE
# undef _DARWIN_C_SOURCE
#endif
/* Enable general extensions on Solaris.  */
#ifndef __EXTENSIONS__
# undef __EXTENSIONS__
#endif
/* Enable GNU extensions on systems that have them.  */
#ifndef _GNU_SOURCE
# undef _GNU_SOURCE
#endif
/* Enable X/Open compliant socket functions that do not require linking
   with -lxnet on HP-UX 11.11.  */
#ifndef _HPUX_ALT_XOPEN_SOCKET_API
# undef _HPUX_ALT_XOPEN_SOCKET_API
#endif
/* Identify the host operating system as Minix.
   This macro does not affect the system headers' behavior.
   A future release of Autoconf may stop defining this macro.  */
#ifndef _MINIX
# undef _MINIX
#endif
/* Enable general extensions on NetBSD.
   Enable NetBSD compatibility extensions on Minix.  */
#ifndef _NETBSD_SOURCE
# undef _NETBSD_SOURCE
#endif
/* Enable OpenBSD compatibility extensions on NetBSD.
   Oddly enough, this does nothing on OpenBSD.  */
#ifndef _OPENBSD_SOURCE
# undef _OPENBSD_SOURCE
#endif
/* Define to 1 if needed for POSIX-compatible behavior.  */
#ifndef _POSIX_SOURCE
# undef _POSIX_SOURCE
#endif
/* Define to 2 if needed for POSIX-compatible behavior.  */
#ifndef _POSIX_1_SOURCE
# undef _POSIX_1_SOURCE
#endif
/* Enable POSIX-compatible threading on Solaris.  */
#ifndef _POSIX_PTHREAD_SEMANTICS
# undef _POSIX_PTHREAD_SEMANTICS
#endif
/* Enable extensions specified by ISO/IEC TS 18661-5:2014.  */
#ifndef __STDC_WANT_IEC_60559_ATTRIBS_EXT__
# undef __STDC_WANT_IEC_60559_ATTRIBS_EXT__
#endif
/* Enable extensions specified by ISO/IEC TS 18661-1:2014.  */
#ifndef __STDC_WANT_IEC_60559_BFP_EXT__
# undef __STDC_WANT_IEC_60559_BFP_EXT__
#endif
/* Enable extensions specified by ISO/IEC TS 18661-2:2015.  */
#ifndef __STDC_WANT_IEC_60559_DFP_EXT__
# undef __STDC_WANT_IEC_60559_DFP_EXT__
#endif
/* Enable extensions specified by ISO/IEC TS 18661-4:2015.  */
#ifndef __STDC_WANT_IEC_60559_FUNCS_EXT__
# undef __STDC_WANT_IEC_60559_FUNCS_EXT__
#endif
/* Enable extensions specified by ISO/IEC TS 18661-3:2015.  */
#ifndef __STDC_WANT_IEC_60559_TYPES_EXT__
# undef __STDC_WANT_IEC_60559_TYPES_EXT__
#endif
/* Enable extensions specified by ISO/IEC TR 24731-2:2010.  */
#ifndef __STDC_WANT_LIB_EXT2__
# undef __STDC_WANT_LIB_EXT2__
#endif
/* Enable extensions specified by ISO/IEC 24747:2009.  */
#ifndef __STDC_WANT_MATH_SPEC_FUNCS__
# undef __STDC_WANT_MATH_SPEC_FUNCS__
#endif
/* Enable extensions on HP NonStop.  */
#ifndef _TANDEM_SOURCE
# undef _TANDEM_SOURCE
#endif
/* Enable X/Open extensions.  Define to 500 only if necessary
   to make mbstate_t available.  */
#ifndef _XOPEN_SOURCE
# undef _XOPEN_SOURCE
#endif


/* Define if weak symbols should be used */
#undef USE_WEAK_SYMBOLS

/* Version number of package */
#undef VERSION

/* Define WORDS_BIGENDIAN to 1 if your processor stores words with the most
   significant byte first (like Motorola and SPARC, unlike Intel). */
#if defined AC_APPLE_UNIVERSAL_BUILD
# if defined __BIG_ENDIAN__
#  define WORDS_BIGENDIAN 1
# endif
#else
# ifndef WORDS_BIGENDIAN
#  undef WORDS_BIGENDIAN
# endif
#endif

/* Define if words are little endian */
#undef WORDS_LITTLEENDIAN

/* Define if configure will not tell us, for universal binaries */
#undef WORDS_UNIVERSAL_ENDIAN

/* define if bool is a built-in type */
#undef bool

/* Define to empty if `const' does not conform to ANSI C. */
#undef const

/* Define to `__inline__' or `__inline' if that's what the C compiler
   calls it, or to nothing if 'inline' is not supported under any name.  */
#ifndef __cplusplus
#undef inline
#endif

/* Define as a signed integer type capable of holding a process identifier. */
#undef pid_t

/* Define to the equivalent of the C99 'restrict' keyword, or to
   nothing if this is not supported.  Do not define if restrict is
   supported only directly.  */
#undef restrict
/* Work around a bug in older versions of Sun C++, which did not
   #define __restrict__ or support _Restrict or __restrict__
   even though the corresponding Sun C compiler ended up with
   "#define restrict _Restrict" or "#define restrict __restrict__"
   in the previous line.  This workaround can be removed once
   we assume Oracle Developer Studio 12.5 (2016) or later.  */
#if defined __SUNPRO_CC && !defined __RESTRICT && !defined __restrict__
# define _Restrict
# define __restrict__
#endif

/* Define to `unsigned int' if <sys/types.h> does not define. */
#undef size_t

/* Define if socklen_t is not defined */
#undef socklen_t

/* Define to empty if the keyword `volatile' does not work. Warning: valid
   code using `volatile' can become incorrect without. Disable with care. */
#undef volatile


/* Include nopackage.h to undef autoconf-defined macros that cause conflicts in
 * subpackages.  This should not be necessary, but some packages are too
 * tightly intertwined right now (such as ROMIO and the MPICH core) */
#include "nopackage.h"

#endif /* !defined(MPICHCONF_H_INCLUDED) */

