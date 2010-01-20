/*-*- Mode: C; c-basic-offset: 8 -*-*/

#include <assert.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <stdlib.h>
#include <arpa/inet.h>
#include <stdio.h>

#include "macro.h"
#include "util.h"
#include "socket-util.h"

int address_parse(Address *a, const char *s) {
        int r;
        char *e, *n;
        unsigned u;

        assert(a);
        assert(s);

        memset(a, 0, sizeof(*a));

        if (*s == '[') {
                /* IPv6 in [x:.....:z]:p notation */

                if (!(e = strchr(s+1, ']')))
                        return -EINVAL;

                if (!(n = strndup(s+1, e-s-1)))
                        return -ENOMEM;

                errno = 0;
                if (inet_pton(AF_INET6, n, &a->sockaddr.in6.sin6_addr) <= 0) {
                        free(n);
                        return errno != 0 ? -errno : -EINVAL;
                }

                free(n);

                e++;
                if (*e != ':')
                        return -EINVAL;

                e++;
                if ((r = safe_atou(e, &u)) < 0)
                        return r;

                if (u <= 0 || u > 0xFFFF)
                        return -EINVAL;

                a->sockaddr.in6.sin6_family = AF_INET6;
                a->sockaddr.in6.sin6_port = htons((uint16_t) u);
                a->size = sizeof(struct sockaddr_in6);
                a->bind_ipv6_only = true;

        } else if (*s == '/') {
                /* AF_UNIX socket */

                size_t l;

                l = strlen(s);
                if (l >= sizeof(a->sockaddr.un.sun_path))
                        return -EINVAL;

                a->sockaddr.un.sun_family = AF_UNIX;
                memcpy(a->sockaddr.un.sun_path, s, l);
                a->size = sizeof(sa_family_t) + l + 1;

        } else if (*s == '=') {
                /* Abstract AF_UNIX socket */
                size_t l;

                l = strlen(s+1);
                if (l >= sizeof(a->sockaddr.un.sun_path) - 1)
                        return -EINVAL;

                a->sockaddr.un.sun_family = AF_UNIX;
                memcpy(a->sockaddr.un.sun_path+1, s+1, l);
                a->size = sizeof(struct sockaddr_un);

        } else {

                if ((e = strchr(s, ':'))) {

                        /* IPv4 in w.x.y.z:p notation */
                        if (!(n = strndup(s, e-s)))
                                return -ENOMEM;

                        errno = 0;
                        if (inet_pton(AF_INET, n, &a->sockaddr.in4.sin_addr) <= 0) {
                                free(n);
                                return errno != 0 ? -errno : -EINVAL;
                        }

                        free(n);

                        e++;
                        if ((r = safe_atou(e, &u)) < 0)
                                return r;

                        if (u <= 0 || u > 0xFFFF)
                                return -EINVAL;

                        a->sockaddr.in4.sin_family = AF_INET;
                        a->sockaddr.in4.sin_port = htons((uint16_t) u);
                        a->size = sizeof(struct sockaddr_in);
                } else {

                        /* Just a port */
                        if ((r = safe_atou(s, &u)) < 0)
                                return r;

                        if (u <= 0 || u > 0xFFFF)
                                return -EINVAL;

                        a->sockaddr.in6.sin6_family = AF_INET6;
                        memcpy(&a->sockaddr.in6.sin6_addr, &in6addr_any, INET6_ADDRSTRLEN);
                        a->sockaddr.in6.sin6_port = htons((uint16_t) u);
                        a->size = sizeof(struct sockaddr_in6);
                }
        }

        return 0;
}

int address_verify(const Address *a) {
        assert(a);

        switch (address_family(a)) {
                case AF_INET:
                        if (a->size != sizeof(struct sockaddr_in))
                                return -EINVAL;

                        if (a->sockaddr.in4.sin_port == 0)
                                return -EINVAL;

                        return 0;

                case AF_INET6:
                        if (a->size != sizeof(struct sockaddr_in6))
                                return -EINVAL;

                        if (a->sockaddr.in6.sin6_port == 0)
                                return -EINVAL;

                        return 0;

                case AF_UNIX:
                        if (a->size < sizeof(sa_family_t))
                                return -EINVAL;

                        if (a->size > sizeof(sa_family_t)) {

                                if (a->sockaddr.un.sun_path[0] == 0) {
                                        /* abstract */
                                        if (a->size != sizeof(struct sockaddr_un))
                                                return -EINVAL;
                                } else {
                                        char *e;

                                        /* path */
                                        if (!(e = memchr(a->sockaddr.un.sun_path, 0, sizeof(a->sockaddr.un.sun_path))))
                                                return -EINVAL;

                                        if (a->size != sizeof(sa_family_t) + (e - a->sockaddr.un.sun_path) + 1)
                                                return -EINVAL;
                                }
                        }

                        return 0;

                default:
                        return -EAFNOSUPPORT;
        }
}

int address_print(const Address *a, char **p) {
        int r;
        assert(a);
        assert(p);

        if ((r = address_verify(a)) < 0)
                return r;

        switch (address_family(a)) {
                case AF_INET: {
                        char *ret;

                        if (!(ret = new(char, INET_ADDRSTRLEN+1+5+1)))
                                return -ENOMEM;

                        if (!inet_ntop(AF_INET, &a->sockaddr.in4.sin_addr, ret, INET_ADDRSTRLEN)) {
                                free(ret);
                                return -errno;
                        }

                        sprintf(strchr(ret, 0), ":%u", ntohs(a->sockaddr.in4.sin_port));
                        *p = ret;
                        return 0;
                }

                case AF_INET6: {
                        char *ret;

                        if (!(ret = new(char, 1+INET6_ADDRSTRLEN+2+5+1)))
                                return -ENOMEM;

                        ret[0] = '[';
                        if (!inet_ntop(AF_INET6, &a->sockaddr.in6.sin6_addr, ret+1, INET6_ADDRSTRLEN)) {
                                free(ret);
                                return -errno;
                        }

                        sprintf(strchr(ret, 0), "]:%u", ntohs(a->sockaddr.in6.sin6_port));
                        *p = ret;
                        return 0;
                }

                case AF_UNIX: {
                        char *ret;

                        if (a->size <= sizeof(sa_family_t)) {

                                if (!(ret = strdup("<unamed>")))
                                        return -ENOMEM;

                        } else if (a->sockaddr.un.sun_path[0] == 0) {
                                /* abstract */

                                /* FIXME: We assume we can print the
                                 * socket path here and that it hasn't
                                 * more than one NUL byte. That is
                                 * actually an invalid assumption */

                                if (!(ret = new(char, sizeof(a->sockaddr.un.sun_path)+1)))
                                        return -ENOMEM;

                                ret[0] = '=';
                                memcpy(ret+1, a->sockaddr.un.sun_path+1, sizeof(a->sockaddr.un.sun_path)-1);
                                ret[sizeof(a->sockaddr.un.sun_path)] = 0;

                        } else {

                                if (!(ret = strdup(a->sockaddr.un.sun_path)))
                                        return -ENOMEM;
                        }

                        *p = ret;
                        return 0;
                }

                default:
                        return -EINVAL;
        }
}

int address_listen(const Address *a, int backlog) {
        int r, fd;
        assert(a);

        if ((r = address_verify(a)) < 0)
                return r;

        if ((fd = socket(address_family(a), a->type, 0)) < 0)
                return -errno;

        if (bind(fd, &a->sockaddr.sa, a->size) < 0) {
                close_nointr(fd);
                return -errno;
        }

        if (a->type == SOCK_STREAM)
                if (listen(fd, backlog) < 0) {
                        close_nointr(fd);
                        return -errno;
                }

        if (address_family(a) == AF_INET6) {
                int flag = a->bind_ipv6_only;

                if (setsockopt(fd, IPPROTO_IPV6, IPV6_V6ONLY, &flag, sizeof(flag)) < 0) {
                        close_nointr(fd);
                        return -errno;
                }
        }

        return 0;
}