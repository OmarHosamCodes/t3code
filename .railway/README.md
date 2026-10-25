# Railway infrastructure

`.railway/railway.ts` is the source of truth for the T3 Code service in the Internal Tools project, Usefull environment.

This file exports `partial = "t3-code"`. The environment also runs other services, and a partial only creates, updates, and deletes resources it owns. Applying it does not touch those other services.

`T3_SETUP_PASSWORD` uses `preserve()`, so the value stays in Railway and is not stored in git.

Preview and apply from this directory:

```bash
railway config plan
railway config apply
```

Do not apply a plan that deletes the volume or replaces `T3_SETUP_PASSWORD`.
