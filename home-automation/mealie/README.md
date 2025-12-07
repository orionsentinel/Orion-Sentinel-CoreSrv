# Mealie - Recipe Management

## Overview

Mealie is a self-hosted recipe manager and meal planner focused on simplicity and ease of use.

## Features

- **Recipe Management**: Import recipes from URLs or add manually
- **Meal Planning**: Plan meals for the week
- **Shopping Lists**: Auto-generate shopping lists from recipes
- **Categories & Tags**: Organize recipes
- **Search**: Full-text search across all recipes
- **Multi-user**: Support for multiple users and households
- **Recipe Scaling**: Automatically scale ingredient quantities
- **Print View**: Clean print layout for recipes

## Access

- Web UI: `https://mealie.local`
- Default credentials (change on first login):
  - Email: `admin@local`
  - Password: `changeme`

## First-Time Setup

1. Access `https://mealie.local`
2. Log in with default credentials
3. Change admin password immediately
4. Create your household and group
5. (Optional) Disable new signups in settings once setup is complete

## Importing Recipes

### From URL

1. Click "Create" → "Recipe from URL"
2. Paste recipe URL (works with most recipe sites)
3. Click "Import"
4. Edit and save

### Manually

1. Click "Create" → "New Recipe"
2. Fill in details
3. Add ingredients and instructions
4. Save

## Meal Planning

1. Go to "Meal Plan" section
2. Click on a day/meal
3. Select a recipe or create a new one
4. View weekly plan

## Shopping Lists

1. Add items manually or from recipes
2. Check off items as you shop
3. Organize by categories

## Mobile Access

Mealie works great on mobile browsers. Add to your home screen for app-like experience.

## Backup

Recipe data is stored in: `${CONFIG_ROOT}/mealie/`

Regular backups recommended for your recipe collection!

## Integration with Home Assistant

You can display your meal plan and shopping list in Home Assistant:

1. Use Home Assistant's REST sensor to fetch from Mealie API
2. Create a Lovelace card to display upcoming meals
3. Show shopping list items in a to-do list card

## Resources

- Documentation: https://docs.mealie.io/
- GitHub: https://github.com/mealie-recipes/mealie
