# CIPP-API Deployment Guide

## Branch Strategy and Azure Function App Deployments

This repository uses a multi-branch deployment strategy with automated GitHub Actions workflows.

## Which Branch Should I Use?

### For Your Function App: **cippza65i**

**Use the `master` branch** ✅

The Azure Function App `cippza65i` is configured to deploy from the **`master`** branch.

- **Function App Name:** `cippza65i`
- **Resource Group:** `CIPP`
- **Workflow File:** `.github/workflows/master_cippza65i.yml`
- **Trigger:** Automatic deployment on push to `master` branch
- **Environment:** Production
- **Portal URL:** https://portal.azure.com/#@simplafitech.com/resource/subscriptions/78afd426-9cc2-46c7-aba4-4125f2ab1ff5/resourceGroups/CIPP/providers/Microsoft.Web/sites/cippza65i

## Complete Branch Strategy

### Production Branch: `master`

**Deploys to:**
- Function App: `cippza65i` (Production)
- Workflow: `.github/workflows/master_cippza65i.yml`
- Also triggers release notes generation and Azure Blob uploads

**When to use:**
- Production-ready code
- Stable releases
- Code that has been tested in development

**Workflow triggers:**
```yaml
on:
  push:
    branches:
      - master
  workflow_dispatch:  # Manual trigger available
```

### Development Branch: `dev`

**Deploys to:**
- Function App: `cippjta72` (Development)
- Workflow: `.github/workflows/dev_api.yml`

**When to use:**
- Development and testing
- New features in progress
- Code that needs validation before production

**Workflow triggers:**
```yaml
on:
  push:
    branches:
      - dev
  workflow_dispatch:  # Manual trigger available
```

### Pre-Release Branch: `pre-release`

**Purpose:**
- Beta releases
- Release candidate testing
- Workflow: `.github/workflows/publish_prerelease.yml`

**When to use:**
- Testing release candidates
- Beta versions for early adopters

## How to Deploy

### Automatic Deployment

1. **Commit your changes** to the appropriate branch
2. **Push to the remote repository**
   ```bash
   git push origin master   # For production (cippza65i)
   git push origin dev      # For development (cippjta72)
   ```
3. **GitHub Actions automatically deploys** - Check the Actions tab for progress

### Manual Deployment

You can also trigger deployments manually:

1. Go to **GitHub Actions** tab in your repository
2. Select the workflow:
   - "Deploy CIPP API to Azure Function App" for `cippza65i`
   - "dev_api" for development
3. Click **"Run workflow"**
4. Select the branch and click **"Run workflow"**

## Deployment Secrets

The following secrets must be configured in GitHub repository settings:

### For Production (`cippza65i`):
- `AZUREAPPSERVICE_PUBLISHPROFILE_CIPPZA65I` - Azure publish profile

### For Development (`cippjta72`):
- `DEV_CLIENTID` - Azure service principal client ID
- `DEV_TENANTID` - Azure tenant ID
- `DEV_SUBSCRIPTIONID` - Azure subscription ID

### For Release Workflows:
- `AZURE_CONNECTION_STRING` - Azure Blob Storage connection string

## Checking Deployment Status

### Via GitHub Actions:
1. Go to the **Actions** tab in your repository
2. Look for the latest workflow run
3. Click on the run to see detailed logs
4. Green checkmark ✅ = successful deployment
5. Red X ❌ = failed deployment (click for details)

### Via Azure Portal:
1. Navigate to your Function App in Azure Portal
2. Check **Deployment Center** for deployment history
3. View **Log stream** for real-time application logs
4. Check **Overview** to verify the app is running

## Common Deployment Scenarios

### Scenario 1: Deploying a New Feature to Production
```bash
# Work on feature branch
git checkout -b feature/my-new-feature

# Make changes and commit
git add .
git commit -m "Add new feature"

# Merge to master when ready
git checkout master
git merge feature/my-new-feature
git push origin master

# Automatic deployment to cippza65i begins
```

### Scenario 2: Testing in Development First
```bash
# Merge to dev branch first
git checkout dev
git merge feature/my-new-feature
git push origin dev

# Test in cippjta72 Function App
# When validated, merge to master for production
```

### Scenario 3: Hotfix for Production
```bash
# Create hotfix branch from master
git checkout master
git checkout -b hotfix/critical-fix

# Make fix and commit
git add .
git commit -m "Fix critical issue"

# Merge back to master
git checkout master
git merge hotfix/critical-fix
git push origin master

# Automatic deployment to cippza65i
```

## Rollback Procedures

If you need to rollback a deployment:

### Option 1: Deploy Previous Commit
```bash
# Find the last good commit
git log --oneline

# Reset to that commit
git reset --hard <commit-hash>

# Force push (use with caution)
git push origin master --force
```

### Option 2: Revert the Bad Commit
```bash
# Revert the problematic commit (safer)
git revert <bad-commit-hash>
git push origin master
```

### Option 3: Azure Portal Rollback
1. Go to Function App in Azure Portal
2. Navigate to **Deployment slots** or **Deployment Center**
3. Use the rollback feature if available
4. Or manually deploy a previous version

## Branch Protection Recommendations

Consider enabling branch protection for `master`:
1. Go to repository **Settings** → **Branches**
2. Add rule for `master` branch
3. Enable:
   - Require pull request reviews
   - Require status checks to pass
   - Require branches to be up to date

## Troubleshooting Deployments

### Deployment Fails

1. **Check GitHub Actions logs** for error messages
2. **Verify secrets** are correctly configured
3. **Check Azure Function App** is running and accessible
4. **Review TROUBLESHOOTING.md** for common issues

### Deployment Succeeds but App Doesn't Work

1. **Check Azure Function App logs** in Portal
2. **Verify application settings** in Function App configuration
3. **Check CORS settings** if receiving 503 errors
4. **Review TROUBLESHOOTING.md** for 503 error solutions

### Deployment is Slow

- Azure Functions may experience "cold starts"
- First deployment after idle period takes longer
- Consider using Premium or Dedicated App Service Plans

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure Functions Deployment](https://learn.microsoft.com/en-us/azure/azure-functions/functions-continuous-deployment)
- [CIPP Documentation](https://docs.cipp.app)
- See `TROUBLESHOOTING.md` for runtime issues

## Quick Reference

| What | Branch | Function App | Workflow |
|------|--------|--------------|----------|
| **Your Production App** | `master` | `cippza65i` | `master_cippza65i.yml` |
| Development | `dev` | `cippjta72` | `dev_api.yml` |
| Pre-releases | `pre-release` | (Blob storage) | `publish_prerelease.yml` |
| Releases | `master` | (Blob storage) | `publish_release.yml` |

---

**Answer to "What branch should I use?"**

For Function App `cippza65i`: Use the **`master`** branch ✅
