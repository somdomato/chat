#!/bin/bash

ERGO_PATH="/usr/share/ergo"
KIWI_PATH="/usr/share/kiwiirc"
KIWI_ETC_PATH="/etc/kiwiirc"
GAMJA_PATH="/usr/share/gamja"

# Systemd
rsync -avzz kiwiirc/etc/systemd/system/ root@eris:/etc/systemd/system/

### KiwiIRC
rsync -avzz kiwiirc$KIWI_ETC_PATH/ root@eris:$KIWI_ETC_PATH/
rsync -avzz kiwiirc$KIWI_PATH/ root@eris:$KIWI_PATH/ --delete
rsync -avzz ergo$ERGO_PATH/ root@eris:$ERGO_PATH/

### ERGO
# ssh root@eris "mkdir -p /etc/letsencrypt/renewal-hooks/deploy/"
rsync -avzz ergo$ERGO_PATH/ root@eris:$ERGO_PATH/

### ERGO
# ssh root@eris "mkdir -p /etc/letsencrypt/renewal-hooks/deploy/"
rsync -avzz gamja$GAMJA_PATH/ root@eris:$GAMJA_PATH/ --exclude="node_modules/" --delete

# Ergo Letsencrypt
scp ergo/etc/letsencrypt/renewal-hooks/deploy/install-ergo-certificates root@eris:/etc/letsencrypt/renewal-hooks/deploy/

# Nginx
scp kiwiirc/etc/nginx/sites.d/06-chat.somdomato.com root@eris:/etc/nginx/sites.d/
scp ergo/etc/nginx/sites.d/05-irc.somdomato.com root@eris:/etc/nginx/sites.d/
scp gamja/etc/nginx/sites.d/07-gamja.somdomato.com root@eris:/etc/nginx/sites.d/

# ssh root@eris "chown -R ergo:ergo $ERGO_PATH && chown -R kiwiirc:kiwiirc $KIWI_PATH"
ssh root@eris "systemctl restart ergo kiwiirc nginx"
