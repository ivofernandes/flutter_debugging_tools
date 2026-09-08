# Example

The SQLite playground uses a seeded project-management database rather than a
single flat table. Open **SQLite screen**, then the debugging drawer, to inspect
teams, users, projects, tasks, tags, their many-to-many junction table, indexes,
and the aggregated `project_summary` view. The schema intentionally includes
foreign-key delete actions, unique and check constraints, defaults, nullable
relationships, and several SQLite value types so edits in the browser behave
like edits against a production database.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
