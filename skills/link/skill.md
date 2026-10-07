---
name: link
description: "Link by Stripe through the link-cli command on the person's own computer: their transactions, balances and connected accounts, and payments they approve in the Link app"

# No token here. link-cli is already signed in to Link on the person's
# machine, as them, so this skill carries no credential, stores none on the
# server, and can do exactly what they granted link-cli when they signed in.
#
# Every call runs on a computer of theirs, never on the server, and each is
# judged before it runs: reading transactions, balances and insights goes
# ahead, cancelling a spend request is a change of theirs that goes ahead,
# and anything that pays asks first. Link then asks again: every spend
# request waits for the person to approve it in the Link app.
#
# Two things are left out on purpose. No call asks Link for card numbers
# (no --include card, no --output-file), so a card never reaches the model,
# and no call passes --approve, which would approve on the person's behalf
# instead of asking them.
#
# Every command asks for JSON, which is what can be read back. Amounts are in
# cents. Limits and cursors are written into the commands: a skill's
# arguments are all or nothing, and an empty one would reach link-cli as an
# empty word.
tools:
  - name: link_transactions
    description: The person's transactions from Link and from the bank and card accounts they connected to Link, newest first, 100 at a time, between two days. Amounts are in cents, money out negative. When the answer says has_more, ask again with more and the id of the last transaction shown.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["list", "more"]
          description: list reads the newest 100 in the range; more reads the next 100 after a transaction
        start_date:
          type: string
          description: The first day, as YYYY-MM-DD
        end_date:
          type: string
          description: The last day, as YYYY-MM-DD
        after_transaction_id:
          type: string
          description: For more - the id of the last transaction the previous answer showed
      required: ["action", "start_date", "end_date"]
    actions:
      list:
        - name: list
          type: shell
          command: [link-cli, transactions, list, --start-date, "{{start_date}}", --end-date, "{{end_date}}", --limit, "100", --format, json]
          timeout: 60
      more:
        - name: more
          type: shell
          command: [link-cli, transactions, list, --start-date, "{{start_date}}", --end-date, "{{end_date}}", --limit, "100", --starting-after, "{{after_transaction_id}}", --format, json]
          timeout: 60

  - name: link_insights
    description: Insights Link has already worked out from the person's spending, such as the brands they buy from most. types lists the insights Link offers with their ids; list reads the person's insights.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["types", "list"]
          description: types lists the insight ids Link offers; list reads the person's insights
      required: ["action"]
    actions:
      types:
        - name: types
          type: shell
          command: [link-cli, insights, list-available-types, --limit, "100", --format, json]
          timeout: 60
      list:
        - name: list
          type: shell
          command: [link-cli, insights, list, --limit, "100", --format, json]
          timeout: 60

  - name: link_accounts
    description: The person's money in Link - balances of their connected accounts (in cents, with when each was read), the connected sources themselves, or the payment methods in their Link wallet (brand and last four digits only).
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["balances", "sources", "payment_methods"]
          description: balances reads what each connected account holds or owes; sources lists the connected accounts; payment_methods lists the cards and banks Link can pay with
      required: ["action"]
    actions:
      balances:
        - name: balances
          type: shell
          command: [link-cli, balances, list, --limit, "100", --format, json]
          timeout: 60
      sources:
        - name: sources
          type: shell
          command: [link-cli, sources, list, --limit, "100", --format, json]
          timeout: 60
      payment_methods:
        - name: payment_methods
          type: shell
          command: [link-cli, payment-methods, list, --format, json]
          timeout: 60

  - name: link_spend_requests
    description: The person's Link spend requests - the payments they were asked to approve. active lists the ones still open, history every one including finished and expired, retrieve reads one by its id (lsrq_...), and cancel withdraws one that is no longer wanted.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["active", "history", "retrieve", "cancel"]
          description: active and history list spend requests; retrieve reads one; cancel withdraws one
        spend_request_id:
          type: string
          description: For retrieve and cancel - the spend request's id, lsrq_...
      required: ["action"]
    actions:
      active:
        - name: active
          type: shell
          command: [link-cli, spend-request, list, --format, json]
          timeout: 60
      history:
        - name: history
          type: shell
          command: [link-cli, spend-request, list, --include-history, --format, json]
          timeout: 60
      retrieve:
        - name: retrieve
          type: shell
          command: [link-cli, spend-request, retrieve, "{{spend_request_id}}", --format, json]
          timeout: 60
      cancel:
        - name: cancel
          type: shell
          command: [link-cli, spend-request, cancel, "{{spend_request_id}}", --format, json]
          timeout: 60

  - name: link_pay
    description: Pay with the person's Link wallet. This spends their money, so say what it will pay, to whom and how much before calling it, and only for a purchase they asked for. card asks Link for a one-time card for a merchant; url pays an address that answers HTTP 402 with a machine payment challenge; report tells Link how a purchase attempt ended. Link asks the person to approve each payment in the Link app and waits up to two minutes; if the answer is still pending, check it later with link_spend_requests retrieve. The card's number is never returned here.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["card", "url", "report"]
          description: card requests a one-time card for a merchant; url pays a 402 address; report records how an attempt ended
        merchant_name:
          type: string
          description: For card - the merchant, as the person would recognize it
        merchant_url:
          type: string
          description: For card - the merchant's website
        amount_cents:
          type: string
          description: For card - the total in cents, such as 2599 for 25.99
        currency:
          type: string
          description: For card - the three-letter currency code in lowercase, such as usd
        url:
          type: string
          description: For url - the address to pay
        context:
          type: string
          description: For card and url - at least 100 characters saying what is being bought and why; the person reads this in the Link app when approving
        domain:
          type: string
          description: For report - the merchant's domain
        outcome:
          type: string
          description: For report - success, blocked or abandoned
        spend_request_id:
          type: string
          description: For report - the spend request the attempt used, lsrq_...
      required: ["action"]
    actions:
      card:
        - name: card
          type: shell
          command: [link-cli, spend-request, create, --credential-type, card, --merchant-name, "{{merchant_name}}", --merchant-url, "{{merchant_url}}", --amount, "{{amount_cents}}", --currency, "{{currency}}", --context, "{{context}}", --format, json]
          timeout: 120
      url:
        - name: url
          type: shell
          command: [link-cli, mpp, pay, "{{url}}", --context, "{{context}}", --format, json]
          timeout: 120
      report:
        - name: report
          type: shell
          command: [link-cli, report, --domain, "{{domain}}", --outcome, "{{outcome}}", --spend-request-id, "{{spend_request_id}}", --format, json]
          timeout: 60

  - name: link_new_transactions
    description: The person's transactions in Link and their connected accounts dated from a day to today, each with its id, its day, whom it was with, the amount and whether money went out or came in. For keeping watch; link_transactions is for looking things up.
    type: shell
    parameters:
      type: object
      properties:
        since_date:
          type: string
          description: The first day, as YYYY-MM-DD
      required: ["since_date"]
    # Shaped into the items a watch reads, amounts in the currency rather
    # than in cents. A transaction keeps its id from pending to posted, and
    # is not watched again when it posts.
    command:
      - sh
      - -c
      - 'link-cli transactions list --start-date "$0" --end-date "$(date +%F)" --limit 100 --format json | jq -c "$1"'
      - "{{since_date}}"
      - '[.data[]? | {id, at: .created_date, from: .description, title: ("\(if .amount < 0 then "-" else "" end)\((if .amount < 0 then -.amount else .amount end) / 100) \(.currency | ascii_upcase)"), text: ("\(if .amount < 0 then "Money out" else "Money in" end): \(.description), \((if .amount < 0 then -.amount else .amount end) / 100) \(.currency | ascii_upcase), on \(.created_date), category \(.category), \(.status)")}]'
    timeout: 60

watches:
  - name: new_transactions
    description: new transactions on their cards and bank accounts in Link
    kind: item
    # A card transaction often appears a day or two after the day it is
    # dated, so each look reaches three days back; what was already seen is
    # not judged again.
    overlap: 72h
    guidance: |
      Worth telling now: a charge they may not have made - a merchant they do not use, a place far from where they live, a run of small charges from one merchant, a large charge out of their usual pattern. Worth telling today: a refund or a deposit they are likely waiting for, a payment to them, a fee or interest charge, a charge noticeably larger than they usually pay that merchant. Not worth telling: their ordinary spending - groceries, restaurants, subscriptions and bills they pay every month, transfers between their own accounts - which is nearly everything.
    list: {tool: link_new_transactions}
---

# Link

The person's [Link](https://link.com) wallet by Stripe, through
[link-cli](https://github.com/stripe/link-cli) on their own computer. Install
it there with `npm install -g @stripe/link-cli` and sign in once, granting
both payments and the read access:

    link-cli auth login --client-name "TeaNode" \
      --scope "userinfo:read payment_methods.agentic" \
      --source-actions read_link_transactions \
      --source-actions read_external_transactions \
      --source-actions read_balances \
      --source-actions read_source_details

Approve the connection in the Link app, then run the command it prints to
finish. `link-cli auth status` shows what was granted.

Reading transactions, balances, sources and insights goes ahead. Paying asks
first, every time, and Link asks the person again in the Link app before any
money moves. Card numbers are never fetched, so they never reach the model.
