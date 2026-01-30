# CIPP-API Troubleshooting Guide

## 503 Service Unavailable Error from Static Web App

If you're experiencing "503 Service Unavailable" errors when accessing the CIPP-API from your Azure Static Web App, follow these steps:

### 1. Update host.json Configuration

This repository now includes proper HTTP extensions configuration in `host.json` that helps the Azure Function handle requests from static web apps more reliably. Make sure you have the latest version deployed.

### 2. Configure CORS in Azure Portal

**Critical**: You must configure CORS (Cross-Origin Resource Sharing) in your Azure Function App to allow requests from your static web app.

#### Steps:
1. Open the [Azure Portal](https://portal.azure.com)
2. Navigate to your CIPP-API Function App
3. In the left menu, select **CORS** (under API section)
4. Add your Static Web App URL to the allowed origins:
   - Example: `https://your-cipp-app.azurestaticapps.net`
   - For multiple environments, add each URL separately
5. Click **Save**
6. Wait 1-2 minutes for changes to propagate (changes take effect immediately, but propagation ensures consistency)

**Security Note**: Do NOT use `*` (allow all origins) in production. Always specify exact origins.

### 3. Verify Function App is Running

1. In Azure Portal, go to your Function App
2. Check the **Overview** page - status should be "Running"
3. If stopped, click **Start**
4. Check **Diagnose and solve problems** for any errors

### 4. Check Application Settings

Ensure these critical settings are configured:
- `AzureWebJobsStorage` - Connection string for storage account
- `FUNCTIONS_WORKER_RUNTIME` - Should be `powershell`
- `FUNCTIONS_EXTENSION_VERSION` - Should be `~4`
- All CIPP-specific settings (client ID, tenant ID, etc.)

### 5. Monitor Logs

Enable and check logs to identify specific issues:
1. Go to Function App > **Log stream** in Azure Portal
2. Or use **Application Insights** if enabled
3. Look for startup errors, authentication issues, or dependency problems

### 6. Common Causes of 503 Errors

- **CORS not configured**: Most common cause - see step 2 above
- **Cold start**: First request after idle period may timeout - retry after 30 seconds
- **Missing secrets**: Verify all required secrets are configured in Azure Portal
- **Resource exhaustion**: Check if you need to scale up your App Service Plan
- **Deployment issues**: Verify the latest code is deployed successfully

### 7. Test the API Directly

To verify the Function App itself is working:
1. Get your Function App URL from Azure Portal
2. Try accessing: `https://your-function-app.azurewebsites.net/api/version`
3. If this works but static app still gets 503, it's a CORS issue

### Additional Resources

- [CIPP Documentation](https://docs.cipp.app)
- [Azure Functions CORS Documentation](https://learn.microsoft.com/en-us/azure/azure-functions/functions-how-to-use-azure-function-app-settings#cors)
- [Azure Static Web Apps Documentation](https://learn.microsoft.com/en-us/azure/static-web-apps/)
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Branch strategy and deployment guide

## Other Common Issues

### Authentication Errors
- Verify GDAP relationships are active
- Check that service principal has correct permissions
- Ensure credentials haven't expired

### Performance Issues
- Review function timeout settings in `host.json`
- Consider scaling your Function App
- Check for long-running operations that should be async

### Deployment Issues
- Verify GitHub Actions workflows completed successfully
- Check for any errors in workflow logs
- Ensure all required secrets are set in GitHub repository settings
- **See [DEPLOYMENT.md](DEPLOYMENT.md) for complete branch and deployment strategy**

---

For more help, visit the [CIPP GitHub Issues](https://github.com/KelvinTegelaar/CIPP-API/issues) page.
