# Backlog

## Example Feature: Smart Product Swapper

### User Story
As a Salesforce CPQ user, I want a swap action that replaces a legacy quote line item with a new product SKU while inheriting the same legacy discount percentage, so the quote preserves negotiated discount intent.

### Acceptance Criteria
- Object context is a `Quote` with related `QuoteLine` items.
- User can invoke the action through the Agentforce conversational interface.
- User provides the SKU of the new replacement product.
- The agent identifies the legacy quote line and its discount percentage.
- The new quote line is created with the same discount percentage as the legacy line, regardless of the new product's List Price.
- The swap preserves discount percentage, not just discount amount.
- The swap respects CPQ Price Rules and does not bypass Advanced Approvals.
- The quote triggers `Recalculate`/rerate logic as needed after line replacement.
- If the quote requires re-approval, the swap action triggers the appropriate approval flow.
- Legacy quote line is deactivated/removed according to business rules (TBD).

### Notes
- New product identification by SKU is mandatory.
- Maintain quote-level pricing and approval integrity.
- Preserve legacy discount percentage across products.
- Ensure CPQ Pricebook and `PricebookEntry` setup is covered by reusable test utilities.
- Do not hardcode IDs or secrets.
