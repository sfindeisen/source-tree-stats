# source-tree-stats
Source code tree statistics generator (number of lines etc.).

Directory tree statistics. Following statistics are available:
* number of files
* number of lines (non-empty/all) (for plain files).

Usage (example):
  ./treeStats.pl --fileExt .java,.xml --verbose <dir>

fileExt is a comma-separated filename suffix filter (skip to
include all files).
