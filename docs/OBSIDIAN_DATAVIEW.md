# Obsidian Dataview for R0lling exports

**Status:** Documentation for the existing one-way daily-note export. It does not change export behavior or add note data.

## Frontmatter written by the bridge

When a daily note is first created, ObsidianVaultBridge.mergeEntryIntoMarkdown writes:

- date: the exported entry's ISO dateKey (YYYY-MM-DD)
- type: daily-journal
- app: R0lling
- tags: [journal, rolling]

The bridge places daily notes under <year>/<month>/<dateKey>.md. It adds later journal entries below the existing frontmatter, so it does not replace metadata in an existing note.

The companion [schema template](examples/Obsidian-Dataview-Template.md) uses YYYY-MM-DD as a format placeholder. It is not a fabricated journal entry or a real export.

## Dataview query

Install and enable the Dataview community plugin in Obsidian, then place this block in a dashboard note:

~~~dataview
TABLE date AS "Ημερομηνία", tags AS "Ετικέτες"
WHERE app = "R0lling" AND type = "daily-journal"
SORT date DESC
~~~

The query scans indexed notes in the vault and returns notes matching the bridge's frontmatter. It shows the date and tags alongside Dataview's default file link. It produces no rows until matching daily notes have been exported and indexed.

Dataview's DQL allows a query type without a FROM clause; WHERE filters pages by fields, and SORT orders the results. See the [Dataview query structure](https://blacksmithgu.github.io/obsidian-dataview/queries/structure/) and [frontmatter metadata](https://blacksmithgu.github.io/obsidian-dataview/data-annotation/).

## Verification boundary

The Swift source defines the frontmatter shape. This guide and template were checked against that source, but the Dataview plugin has not been exercised in an Obsidian vault or on an Apple device.