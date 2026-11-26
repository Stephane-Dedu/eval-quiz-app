# J2 — Scan Trivy de l'état initial

**Date :** 2026-11-26
**Outil :** Trivy 0.76.2, base de vulnérabilités du 2026-11-26
**Images :** construites localement (linux/arm64) depuis les Dockerfiles de la PR « Dockerfiles initiaux » ; `postgres:18` est l'image officielle telle qu'un premier `docker-compose.yml` l'utiliserait.

```console
$ docker build -t quiz-frontend:initial .
$ docker build -t quiz-backend:initial backend
$ trivy image --scanners vuln --format json -o <rapport>.json <image>
```

## Ce que montre ce scan

- **Les vulnérabilités viennent de l'image de base, pas de l'application.** Frontend et backend ont exactement les mêmes chiffres : tout vient de `node:20`, et `npm audit` ne signale aucune vulnérabilité dans les dépendances JavaScript.
- **`node:20` n'est plus maintenue.** Node.js 20 est en fin de vie depuis le 30 avril 2026, donc ses paquets Debian ne reçoivent plus de mises à jour.
- **L'image complète embarque des outils inutiles à l'exécution.** Les en-têtes du noyau (`linux-libc-dev`), ImageMagick et les bibliothèques de développement PostgreSQL servent à compiler, jamais à faire tourner l'application. À eux seuls, ils représentent l'essentiel des CRITICAL et HIGH.
- **Plus d'1 Go par image**, alors que l'application backend pèse quelques Mo de dépendances et le frontend quelques dizaines de Ko de fichiers statiques.
- **`postgres:18` (Debian) est bien plus saine**, mais embarque `gosu`, compilé en Go, dont la bibliothèque standard compte 26 HIGH.

La PR suivante corrige ces points un par un et rescanne après chaque étape.

| Image | Système | Taille | CRITICAL | HIGH | MEDIUM | LOW | CRITICAL corrigeables | HIGH corrigeables |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `quiz-frontend:initial` | debian 12.13 | 1143 Mo | 74 | 1819 | 5985 | 2744 | 54 | 1353 |
| `quiz-backend:initial` | debian 12.13 | 1111 Mo | 74 | 1819 | 5985 | 2744 | 54 | 1353 |
| `postgres:18` | debian 13.8 | 500 Mo | 2 | 99 | 146 | 164 | 1 | 27 |

## `quiz-frontend:initial`

**Paquets les plus touchés (CRITICAL + HIGH)**

| Paquet | Vulnérabilités |
| --- | ---: |
| `linux-libc-dev` | 665 |
| `libpq-dev` | 54 |
| `libpq5` | 54 |
| `imagemagick` | 38 |
| `imagemagick-6-common` | 38 |
| `imagemagick-6.q16` | 38 |
| `libmagickcore-6-arch-config` | 38 |
| `libmagickcore-6-headers` | 38 |
| `libmagickcore-6.q16-6` | 38 |
| `libmagickcore-6.q16-6-extra` | 38 |

<details><summary>Les 74 vulnérabilités CRITICAL</summary>

| CVE | Paquet | Installé | Corrigé dans |
| --- | --- | --- | --- |
| CVE-2026-25971 | `imagemagick` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `imagemagick` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `imagemagick-6-common` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `imagemagick-6-common` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `imagemagick-6.q16` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `imagemagick-6.q16` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2023-6879 | `libaom3` | 3.6.0-1+deb12u2 | pas de correctif |
| CVE-2026-111497 | `libbrotli-dev` | 1.0.9-2+b6 | 1.0.9-2+deb12u1 |
| CVE-2026-111497 | `libbrotli1` | 1.0.9-2+b6 | 1.0.9-2+deb12u1 |
| CVE-2026-58016 | `libglib2.0-0` | 2.74.6-2+deb12u8 | pas de correctif |
| CVE-2026-58016 | `libglib2.0-bin` | 2.74.6-2+deb12u8 | pas de correctif |
| CVE-2026-58016 | `libglib2.0-data` | 2.74.6-2+deb12u8 | pas de correctif |
| CVE-2026-58016 | `libglib2.0-dev` | 2.74.6-2+deb12u8 | pas de correctif |
| CVE-2026-58016 | `libglib2.0-dev-bin` | 2.74.6-2+deb12u8 | pas de correctif |
| CVE-2026-33845 | `libgnutls30` | 3.7.9-2+deb12u6 | 3.7.9-2+deb12u7 |
| CVE-2026-42010 | `libgnutls30` | 3.7.9-2+deb12u6 | 3.7.9-2+deb12u7 |
| CVE-2026-25971 | `libmagickcore-6-arch-config` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickcore-6-arch-config` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickcore-6-headers` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickcore-6-headers` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickcore-6.q16-6` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickcore-6.q16-6` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickcore-6.q16-6-extra` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickcore-6.q16-6-extra` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickcore-6.q16-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickcore-6.q16-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickcore-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickcore-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickwand-6-headers` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickwand-6-headers` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickwand-6.q16-6` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickwand-6.q16-6` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickwand-6.q16-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickwand-6.q16-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickwand-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickwand-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-44172 | `libmariadb-dev` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2026-49261 | `libmariadb-dev` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2026-44172 | `libmariadb-dev-compat` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2026-49261 | `libmariadb-dev-compat` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2026-44172 | `libmariadb3` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2026-49261 | `libmariadb3` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2023-5841 | `libopenexr-3-1-30` | 3.1.5-5 | pas de correctif |
| CVE-2026-42216 | `libopenexr-3-1-30` | 3.1.5-5 | pas de correctif |
| CVE-2026-42217 | `libopenexr-3-1-30` | 3.1.5-5 | pas de correctif |
| CVE-2023-5841 | `libopenexr-dev` | 3.1.5-5 | pas de correctif |
| CVE-2026-42216 | `libopenexr-dev` | 3.1.5-5 | pas de correctif |
| CVE-2026-42217 | `libopenexr-dev` | 3.1.5-5 | pas de correctif |
| CVE-2026-13221 | `libperl5.36` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-42496 | `libperl5.36` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-8376 | `libperl5.36` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2025-7458 | `libsqlite3-0` | 3.40.1-2+deb12u2 | pas de correctif |
| CVE-2025-7458 | `libsqlite3-dev` | 3.40.1-2+deb12u2 | pas de correctif |
| CVE-2026-6653 | `libxml2` | 2.9.14+dfsg-1.3~deb12u5 | pas de correctif |
| CVE-2026-6653 | `libxml2-dev` | 2.9.14+dfsg-1.3~deb12u5 | pas de correctif |
| CVE-2026-43037 | `linux-libc-dev` | 6.1.164-1 | 6.1.170-1 |
| CVE-2026-98432 | `linux-libc-dev` | 6.1.164-1 | 6.1.190-1 |
| CVE-2026-99083 | `linux-libc-dev` | 6.1.164-1 | 6.1.192-1 |
| CVE-2026-99362 | `linux-libc-dev` | 6.1.164-1 | pas de correctif |
| CVE-2026-44172 | `mariadb-common` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2026-49261 | `mariadb-common` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2026-60002 | `openssh-client` | 1:9.2p1-2+deb12u9 | pas de correctif |
| CVE-2026-13221 | `perl` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-42496 | `perl` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-8376 | `perl` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-13221 | `perl-base` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-42496 | `perl-base` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-8376 | `perl-base` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-13221 | `perl-modules-5.36` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-42496 | `perl-modules-5.36` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-8376 | `perl-modules-5.36` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-59873 | `tar` | 6.2.1 | 7.5.19 |
| CVE-2023-45853 | `zlib1g` | 1:1.2.13.dfsg-1 | pas de correctif |
| CVE-2023-45853 | `zlib1g-dev` | 1:1.2.13.dfsg-1 | pas de correctif |

</details>

## `quiz-backend:initial`

**Paquets les plus touchés (CRITICAL + HIGH)**

| Paquet | Vulnérabilités |
| --- | ---: |
| `linux-libc-dev` | 665 |
| `libpq-dev` | 54 |
| `libpq5` | 54 |
| `imagemagick` | 38 |
| `imagemagick-6-common` | 38 |
| `imagemagick-6.q16` | 38 |
| `libmagickcore-6-arch-config` | 38 |
| `libmagickcore-6-headers` | 38 |
| `libmagickcore-6.q16-6` | 38 |
| `libmagickcore-6.q16-6-extra` | 38 |

<details><summary>Les 74 vulnérabilités CRITICAL</summary>

| CVE | Paquet | Installé | Corrigé dans |
| --- | --- | --- | --- |
| CVE-2026-25971 | `imagemagick` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `imagemagick` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `imagemagick-6-common` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `imagemagick-6-common` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `imagemagick-6.q16` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `imagemagick-6.q16` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2023-6879 | `libaom3` | 3.6.0-1+deb12u2 | pas de correctif |
| CVE-2026-111497 | `libbrotli-dev` | 1.0.9-2+b6 | 1.0.9-2+deb12u1 |
| CVE-2026-111497 | `libbrotli1` | 1.0.9-2+b6 | 1.0.9-2+deb12u1 |
| CVE-2026-58016 | `libglib2.0-0` | 2.74.6-2+deb12u8 | pas de correctif |
| CVE-2026-58016 | `libglib2.0-bin` | 2.74.6-2+deb12u8 | pas de correctif |
| CVE-2026-58016 | `libglib2.0-data` | 2.74.6-2+deb12u8 | pas de correctif |
| CVE-2026-58016 | `libglib2.0-dev` | 2.74.6-2+deb12u8 | pas de correctif |
| CVE-2026-58016 | `libglib2.0-dev-bin` | 2.74.6-2+deb12u8 | pas de correctif |
| CVE-2026-33845 | `libgnutls30` | 3.7.9-2+deb12u6 | 3.7.9-2+deb12u7 |
| CVE-2026-42010 | `libgnutls30` | 3.7.9-2+deb12u6 | 3.7.9-2+deb12u7 |
| CVE-2026-25971 | `libmagickcore-6-arch-config` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickcore-6-arch-config` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickcore-6-headers` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickcore-6-headers` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickcore-6.q16-6` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickcore-6.q16-6` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickcore-6.q16-6-extra` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickcore-6.q16-6-extra` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickcore-6.q16-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickcore-6.q16-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickcore-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickcore-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickwand-6-headers` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickwand-6-headers` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickwand-6.q16-6` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickwand-6.q16-6` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickwand-6.q16-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickwand-6.q16-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-25971 | `libmagickwand-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u14 |
| CVE-2026-56367 | `libmagickwand-dev` | 8:6.9.11.60+dfsg-1.6+deb12u8 | 8:6.9.11.60+dfsg-1.6+deb12u12 |
| CVE-2026-44172 | `libmariadb-dev` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2026-49261 | `libmariadb-dev` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2026-44172 | `libmariadb-dev-compat` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2026-49261 | `libmariadb-dev-compat` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2026-44172 | `libmariadb3` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2026-49261 | `libmariadb3` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2023-5841 | `libopenexr-3-1-30` | 3.1.5-5 | pas de correctif |
| CVE-2026-42216 | `libopenexr-3-1-30` | 3.1.5-5 | pas de correctif |
| CVE-2026-42217 | `libopenexr-3-1-30` | 3.1.5-5 | pas de correctif |
| CVE-2023-5841 | `libopenexr-dev` | 3.1.5-5 | pas de correctif |
| CVE-2026-42216 | `libopenexr-dev` | 3.1.5-5 | pas de correctif |
| CVE-2026-42217 | `libopenexr-dev` | 3.1.5-5 | pas de correctif |
| CVE-2026-13221 | `libperl5.36` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-42496 | `libperl5.36` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-8376 | `libperl5.36` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2025-7458 | `libsqlite3-0` | 3.40.1-2+deb12u2 | pas de correctif |
| CVE-2025-7458 | `libsqlite3-dev` | 3.40.1-2+deb12u2 | pas de correctif |
| CVE-2026-6653 | `libxml2` | 2.9.14+dfsg-1.3~deb12u5 | pas de correctif |
| CVE-2026-6653 | `libxml2-dev` | 2.9.14+dfsg-1.3~deb12u5 | pas de correctif |
| CVE-2026-43037 | `linux-libc-dev` | 6.1.164-1 | 6.1.170-1 |
| CVE-2026-98432 | `linux-libc-dev` | 6.1.164-1 | 6.1.190-1 |
| CVE-2026-99083 | `linux-libc-dev` | 6.1.164-1 | 6.1.192-1 |
| CVE-2026-99362 | `linux-libc-dev` | 6.1.164-1 | pas de correctif |
| CVE-2026-44172 | `mariadb-common` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2026-49261 | `mariadb-common` | 1:10.11.14-0+deb12u2 | 1:10.11.18-0+deb12u1 |
| CVE-2026-60002 | `openssh-client` | 1:9.2p1-2+deb12u9 | pas de correctif |
| CVE-2026-13221 | `perl` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-42496 | `perl` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-8376 | `perl` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-13221 | `perl-base` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-42496 | `perl-base` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-8376 | `perl-base` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-13221 | `perl-modules-5.36` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-42496 | `perl-modules-5.36` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-8376 | `perl-modules-5.36` | 5.36.0-7+deb12u3 | 5.36.0-7+deb12u4 |
| CVE-2026-59873 | `tar` | 6.2.1 | 7.5.19 |
| CVE-2023-45853 | `zlib1g` | 1:1.2.13.dfsg-1 | pas de correctif |
| CVE-2023-45853 | `zlib1g-dev` | 1:1.2.13.dfsg-1 | pas de correctif |

</details>

## `postgres:18`

**Paquets les plus touchés (CRITICAL + HIGH)**

| Paquet | Vulnérabilités |
| --- | ---: |
| `stdlib` | 26 |
| `libxml2` | 8 |
| `bsdutils` | 4 |
| `libblkid1` | 4 |
| `liblastlog2-2` | 4 |
| `libmount1` | 4 |
| `libsmartcols1` | 4 |
| `libuuid1` | 4 |
| `login` | 4 |
| `mount` | 4 |

<details><summary>Les 2 vulnérabilités CRITICAL</summary>

| CVE | Paquet | Installé | Corrigé dans |
| --- | --- | --- | --- |
| CVE-2026-6653 | `libxml2` | 2.12.7+dfsg+really2.9.14-2.1+deb13u3 | pas de correctif |
| CVE-2025-68121 | `stdlib` | v1.24.6 | 1.24.13, 1.25.7, 1.26.0-rc.3 |

</details>

