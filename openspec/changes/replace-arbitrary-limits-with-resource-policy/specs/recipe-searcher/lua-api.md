# recipe-searcher resource-policy Lua API amendment

Proposed normative amendment to the existing [API](../../../../specs/recipe-searcher/lua-api.md), with unchanged details retained there unless explicitly replaced below. Shared execution, status and errors: [api-contract.md](../../api-contract.md).

`findRecipes(product_type, product_name [, category])` still returns exactly one dense name-sorted `RecipeInfo[]` with all matches and unchanged ingredient/product metadata. Category filtering remains exact, not a workaround for result capacity. There is no 50-match ceiling or new pagination API. Processing may span work slices without rerunning a completed call.

`getLimits()` omits `recipe_search_results` and exposes resource policy version 2. Capacity/depth refusal is recoverable, work exhaustion suspends, and native invalid arguments/authority remain ordinary typed errors. No result is silently truncated. Candidate prototype identity is captured for a query; enabled-state observations are consistently acquired for that query and authority is revalidated before publication. A mod configuration change invalidating a captured prototype aborts that unfinished query recoverably rather than fabricating data.
