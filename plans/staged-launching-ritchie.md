# Commit & push — fix @Qualifier e @Transactional propagation

## Contesto

2 file gia' staged con fix critici per il corretto funzionamento runtime:

1. **PheromoneService.java** — `@Qualifier("redisMessagingTemplate")` per disambiguare `StringRedisTemplate` (fix bean conflict)
2. **TaskCompletedEventHandler.java** — `@Transactional(propagation = Propagation.REQUIRES_NEW)` per side effects post-commit (fix transaction scope)

File untracked `docker/sol.env` contiene credenziali — **NON committare**.

## Azioni

1. `git commit` dei 2 file staged con messaggio: `fix: qualify StringRedisTemplate + REQUIRES_NEW for side effects`
2. `git push origin main`
