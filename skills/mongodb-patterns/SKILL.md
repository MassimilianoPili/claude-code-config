---
name: mongodb-patterns
description: MongoDB administration patterns for Docker Compose deployment, authentication setup, network aliases, mongo-express GUI configuration, connection strings, and basic CRUD operations in self-hosted environments.
allowed-tools: Read, Write, Bash, Edit
category: database
tags: [mongodb, mongo, nosql, docker, mongo-express, database]
version: 1.0.0
---

# MongoDB Patterns — SOL Server

## Overview

MongoDB 8 runs as the document database on the SOL server, deployed via Docker Compose on the `shared` network. The web GUI is provided by mongo-express 1.x, protected behind OAuth2 Proxy (Keycloak SSO). MongoDB is internal-only — no port is exposed to the host. All access happens through the Docker network or via the nginx reverse proxy for the mongo-express GUI.

- **Stack directory**: `/data/massimiliano/mongodb/`
- **Credentials**: `/data/massimiliano/mongodb/.env`
- **Data directory**: `/data/massimiliano/mongodb/data/`

## When to Use

- Configuring MongoDB as a backend for a new application
- Debugging connection issues between containers and MongoDB
- Managing databases, collections, and users via mongo-express or the CLI
- Understanding the network alias pattern (`mongodb` vs `mongo`)
- Setting up Spring Boot, Node.js, or Go applications with MongoDB
- Performing backup and restore operations

## Docker Compose Configuration

```yaml
services:
  mongodb:
    image: mongo:8
    container_name: mongodb
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_ROOT_USER}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_ROOT_PASSWORD}
    volumes:
      - ./data:/data/db
    networks:
      shared:
        aliases:
          - mongo

  mongo-express:
    image: mongo-express:1
    container_name: mongo-express
    restart: unless-stopped
    depends_on:
      - mongodb
    environment:
      ME_CONFIG_MONGODB_URL: mongodb://${MONGO_ROOT_USER}:${MONGO_ROOT_PASSWORD}@mongodb:27017/
      ME_CONFIG_SITE_BASEURL: /mongo/
      ME_CONFIG_BASICAUTH: "false"
    networks:
      - shared

networks:
  shared:
    external: true
```

### Key Configuration Points

- **Network alias `mongo`**: Provides a backward-compatible DNS name alongside the primary `mongodb` hostname. Both resolve to the same container on the `shared` network.
- **ME_CONFIG_SITE_BASEURL: /mongo/**: mongo-express handles the URL prefix internally (Pattern B in nginx — no prefix stripping required).
- **ME_CONFIG_BASICAUTH: "false"**: Disables mongo-express built-in basic auth. Authentication is delegated to OAuth2 Proxy via nginx `auth_request`.
- **ME_CONFIG_MONGODB_URL**: Full connection string format required by mongo-express 1.x (replaces the older separate host/port/user/pass environment variables).
- **No exposed ports**: MongoDB listens only on the Docker network. No `ports:` directive — access is container-to-container only.

## Connection Patterns

### From Docker Containers (generic)

```text
mongodb://${MONGO_ROOT_USER}:${MONGO_ROOT_PASSWORD}@mongodb:27017/
# or using the network alias:
mongodb://${MONGO_ROOT_USER}:${MONGO_ROOT_PASSWORD}@mongo:27017/
```

For application-specific databases with dedicated users:

```text
mongodb://myapp_user:myapp_password@mongodb:27017/myapp_db?authSource=myapp_db
```

### Spring Boot (Spring Data MongoDB)

```yaml
spring:
  data:
    mongodb:
      uri: mongodb://${MONGO_USER}:${MONGO_PASSWORD}@mongodb:27017/${DB_NAME}
      # or separate properties:
      host: mongodb
      port: 27017
      database: mydb
      username: ${MONGO_USER}
      password: ${MONGO_PASSWORD}
      authentication-database: mydb
```

### Node.js (mongoose)

```javascript
const mongoose = require('mongoose');
await mongoose.connect('mongodb://user:pass@mongodb:27017/mydb', {
  authSource: 'mydb'
});
```

### Go (mongo-driver)

```go
import "go.mongodb.org/mongo-driver/mongo"
import "go.mongodb.org/mongo-driver/mongo/options"

client, err := mongo.Connect(ctx, options.Client().ApplyURI(
    "mongodb://user:pass@mongodb:27017/mydb?authSource=mydb",
))
```

## Access Points

| Access Method | URL / Command |
|---------------|---------------|
| mongo-express (Tailscale) | `http://100.86.46.84/mongo/` |
| mongo-express (Public) | `https://sol.massimilianopili.com/mongo/` |
| CLI from host | `docker exec -it mongodb mongosh -u root -p <pass>` |
| Docker network (primary) | `mongodb:27017` |
| Docker network (alias) | `mongo:27017` |

**Auth for mongo-express**: OAuth2 Proxy -> Keycloak SSO (same flow as pgAdmin, Portainer, etc.)

## Common CLI Operations

### Connect to MongoDB Shell

```bash
docker exec -it mongodb mongosh -u ${MONGO_ROOT_USER} -p ${MONGO_ROOT_PASSWORD}
```

### List Databases

```bash
docker exec mongodb mongosh -u root -p <pass> --quiet --eval "db.adminCommand('listDatabases')"
```

### Create Database and Dedicated User

```bash
docker exec mongodb mongosh -u root -p <pass> --quiet --eval '
  use("myapp");
  db.createUser({
    user: "myapp",
    pwd: "secure-password",
    roles: [{ role: "readWrite", db: "myapp" }]
  });
  print("User myapp created on database myapp");
'
```

### Insert and Query Documents

```bash
docker exec mongodb mongosh -u root -p <pass> --quiet --eval '
  use("myapp");
  db.items.insertOne({ name: "example", created: new Date() });
  printjson(db.items.find().toArray());
'
```

### Drop a Database

```bash
docker exec mongodb mongosh -u root -p <pass> --quiet --eval '
  use("myapp");
  db.dropDatabase();
  print("Database myapp dropped");
'
```

### Backup (mongodump)

```bash
# Dump a specific database
docker exec mongodb mongodump -u root -p <pass> --authenticationDatabase admin \
    --db myapp --out /tmp/backup/

# Copy dump to host
docker cp mongodb:/tmp/backup/ /data/massimiliano/mongodb/backup/
```

### Restore (mongorestore)

```bash
# Copy dump into container
docker cp /data/massimiliano/mongodb/backup/myapp mongodb:/tmp/restore/

# Restore
docker exec mongodb mongorestore -u root -p <pass> --authenticationDatabase admin \
    --db myapp /tmp/restore/myapp/
```

## nginx Configuration

mongo-express uses **Pattern B** (prefix kept, no stripping) because `ME_CONFIG_SITE_BASEURL` makes the application handle the `/mongo/` prefix internally:

```nginx
# Tailscale server block (:80)
location /mongo/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=$request_uri;

    set $mongo_upstream http://mongo-express:8081;
    proxy_pass $mongo_upstream;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    # No rewrite — mongo-express handles /mongo/ prefix via ME_CONFIG_SITE_BASEURL
}

# Public server block (:8888) — same pattern, uses oauth2-proxy-public
location /mongo/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=$request_uri;

    set $mongo_upstream http://mongo-express:8081;
    proxy_pass $mongo_upstream;
    # Same headers as above
}
```

## Environment File (.env)

```bash
# /data/massimiliano/mongodb/.env
MONGO_ROOT_USER=root
MONGO_ROOT_PASSWORD=<generated-secure-password>
```

Keep this file with restricted permissions (`chmod 600`). Never commit credentials to Git.

## Best Practices

1. **Network aliases for compatibility**: Always define the `mongo` alias on the `shared` network. Some libraries and tools expect `mongo` as the default hostname.
2. **Delegate auth to OAuth2 Proxy**: Disable mongo-express basic auth (`ME_CONFIG_BASICAUTH=false`) and protect it with `auth_request` in nginx.
3. **Use `ME_CONFIG_MONGODB_URL`**: mongo-express 1.x requires the full connection string format. The older `ME_CONFIG_MONGODB_SERVER` / `ME_CONFIG_MONGODB_ADMINUSERNAME` variables are deprecated.
4. **Never expose MongoDB to the host**: No `ports:` mapping. All access goes through the Docker `shared` network.
5. **Create dedicated users per application**: Do not share the root credentials with application containers. Create a user with `readWrite` on the specific database.
6. **Use `depends_on`**: Ensure mongo-express starts after mongodb to avoid connection failures on first boot.
7. **Backup regularly**: Use `mongodump` for logical backups. The data directory (`./data`) is also included in the nightly restic backup.

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| mongo-express shows "Could not connect to database" | Wrong `ME_CONFIG_MONGODB_URL` or credentials mismatch | Verify `.env` values match between mongodb and mongo-express services |
| Authentication failed on mongosh | Wrong username/password or wrong authSource | Use `--authenticationDatabase admin` for root, or specify the correct DB for app users |
| Network alias `mongo` not resolving | Missing `aliases` section in docker-compose | Add `aliases: [mongo]` under the `shared` network for the mongodb service |
| Data directory permission errors | MongoDB container writes as UID 999 | Ensure `./data/` is writable by UID 999: `sudo chown -R 999:999 ./data/` |
| mongo-express 502 via nginx | Container not on `shared` network or not running | Check `docker network inspect shared` and `docker ps` for mongo-express |
| mongo-express shows wrong base URL | `ME_CONFIG_SITE_BASEURL` missing or incorrect | Must be `/mongo/` (with trailing slash) |
| Stale DNS in nginx after container recreate | nginx cached old IP (TTL 10s) | Wait 10 seconds or force-recreate nginx: `cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate` |

## Stack Management

```bash
# Start the stack
cd /data/massimiliano/mongodb && docker compose up -d

# Restart with force recreate (after config changes)
cd /data/massimiliano/mongodb && docker compose up -d --force-recreate

# View logs
docker logs mongodb --tail 50
docker logs mongo-express --tail 50 -f

# Check connectivity from another container
docker exec <app-container> mongosh "mongodb://user:pass@mongodb:27017/mydb" --eval "db.runCommand({ping:1})"
```
