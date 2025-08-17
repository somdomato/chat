# 🎧 Rádio Som do Mato (CHAT)

![Rádio Som do Mato](https://raw.githubusercontent.com/somdomato/somdomato/refs/heads/main/public/images/logo.svg "Rádio Som do Mato")

Streaming de audio para as massas.

| sistema | url | descrição | 
| :--- | :---: | ---: |
| [Site](https://github.com/somdomato/somdomato) | [somdomato.com](https://somdomato.com) | |
| [Stream](https://github.com/somdomato/stream) | [radio.somdomato.com](https://radio.somdomato.com) | Arquivos de configuração do Icecast e Liquidsoap |
| Chat | [chat.somdomato.com](https://chat.somdomato.com) | Arquivos de configuração do bate-papo usando IRC(Ergo, Gamja & KiwiIRC)  |
| [Podman](https://github.com/somdomato/podman) | - | Imagens e contêineres do [Podman](https://podman.io) para desenvolvimento local. |

## Instalação

Crie o arquivo `/etc/cloudflare.ini`:
```conf
dns_cloudflare_email   = SEU_EMAIL
dns_cloudflare_api_key = SEU_TOKEN
```

Crie os certificados necessários:

```bash
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/cloudflare.ini -d irc.somdomato.com
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/cloudflare.ini -d chat.somdomato.com
```

