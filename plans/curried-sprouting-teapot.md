# Deploy Playwright ADESSO con PropertiesLauncher

## Piano

1. Dockerfile PropertiesLauncher + .dockerignore
2. Build JAR sull'host
3. Docker build + deploy
4. Verifica Playwright

Le 2 librerie mancanti (recovery, token) si pubblicano dopo — il mirror.yml sui tag causa race condition GPG.
