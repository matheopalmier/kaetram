# Documentation d'Administration Shefira

Ce document récapitule la configuration technique mise en place lors de la restauration du projet en février 2026.

## 1. Hébergement & Système
- **VPS** : OVH (IP: 51.178.42.132)
- **OS** : Ubuntu 22.04.5 LTS
- **Node.js** : v20.x (Indispensable pour la compatibilité avec uWS.js v20)
- **Domaine** : shefira.com / www.shefira.com

## 2. Configuration Nginx (Reverse Proxy)
La configuration se trouve dans `/etc/nginx/sites-available/kaetram`. Elle gère le HTTPS, le Web ou les APIs, et les WebSockets.

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name shefira.com www.shefira.com;
    return 301 https://shefira.com$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name shefira.com www.shefira.com;

    ssl_certificate /etc/letsencrypt/live/shefira.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/shefira.com/privkey.pem;

    root /home/ubuntu/kaetram/packages/client/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /server {
        proxy_pass http://localhost:9526;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /all {
        proxy_pass http://localhost:9526;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /ws {
        proxy_pass http://127.0.0.1:9001/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 3. Gestion des Services (PM2)
Les services sont gérés par PM2. Il est important de les lancer depuis la racine du projet pour que les workspaces Yarn soient correctement détectés.

- **Démarrage/Redémarrage** :
  ```bash
  pm2 restart all
  ```
- **Logs** :
  ```bash
  pm2 logs
  ```
- **Monit** :
  ```bash
  pm2 monit
  ```

## 4. Bibliothèque Réseau (uWS.js)
Le projet utilise `uWS.js` pour les serveurs et le hub.
- **Version actuelle** : `v20.25.0`
- **Correction GLIBC** : Cette version est compatible avec la `GLIBC 2.35+` d'Ubuntu 22.x et Node 20. Ne pas revenir à une version plus ancienne de uWS sans vérifier la compatibilité des binaires.

## 5. Ports Importants
- **80/443** : HTTP/HTTPS (Nginx)
- **9001** : WebSocket Server (Proxyé par Nginx via `/ws`)
- **9526** : Hub API (Proxyé par Nginx via `/all` et `/server`)

## 6. Variables d'Environnement (.env)
Fichier : `/home/ubuntu/kaetram/.env`
- `SSL=true` : Active le protocole `wss://` et `https://` dans le client lors de la compilation.
- `HOST=shefira.com` : Définit le hostname principal.

## 7. Rebranding (Kaetram -> Shefira)
Toutes les références textuelles dans `packages/client/index.html` et les fichiers de config frontend ont été mises à jour. Pour toute nouvelle modification, veiller à utiliser `https://shefira.com` pour les assets.
