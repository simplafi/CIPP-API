# Quick Reference: Which Branch to Use?

## For Azure Function App `cippza65i`

**USE THE `master` BRANCH** ✅

### Details:
- **Function App:** cippza65i
- **Branch:** `master`
- **Workflow:** `.github/workflows/master_cippza65i.yml`
- **Deployment:** Automatic on push to `master` branch

### To Deploy:
```bash
git checkout master
git add .
git commit -m "Your changes"
git push origin master
```

### Complete Documentation:
See **[DEPLOYMENT.md](DEPLOYMENT.md)** for complete branch strategy, deployment procedures, and troubleshooting.

---

## All Branches

| Branch | Function App | Purpose |
|--------|--------------|---------|
| **master** | **cippza65i** | **Production** |
| dev | cippjta72 | Development |
| pre-release | (releases only) | Pre-release testing |
