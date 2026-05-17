# Copilot Instructions for brands-advisory-central-infra
## Language
- All code, comments, variable names, method names, 
  and class names must be in English
- XML documentation comments must be in English
- Git commit messages must be in English
- README and technical documentation must be in English
- Prompts may be written in German or English - 
  always respond and generate code in English regardless

## Security
- Never put real secrets, keys, passwords, or tokens in code
- All sensitive configuration values must use placeholders 
  in the format __PLACEHOLDER_NAME__
- Never hardcode OIDs, Tenant IDs, Client IDs, or 
  Cosmos DB connection strings

## Bicep Tags
- Every Bicep module must include a `tags` parameter with the following default value:
  ```bicep
  param tags object = {
    environment: 'prod'
    tier:        'central'
    project:     'brands-advisory-central-infra'
    'managed-by': 'bicep'
  }
  ```
- The `tags` parameter must be applied to every top-level resource in the module.
- Never hardcode tags directly on resources — always use the `tags` parameter.

## Documentation
- Keep README.md up to date when adding new features, new modules, new scripts,
  configuration values, or deployment steps
- Add XML doc comments to all public interfaces and methods
- Document any new __PLACEHOLDER__ values in README.md 
  under the Setup section


  