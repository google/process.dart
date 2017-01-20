#!/bin/bash

# Make sure dartfmt is run on everything
echo "Checking dartfmt..."
needs_dartfmt="$(dartfmt -n lib test tools)"
if [[ -n "$needs_dartfmt" ]]; then
  echo "FAILED"
  echo "$needs_dartfmt"
  exit 1
fi
echo "PASSED"

# Make sure we pass the analyzer
echo "Checking dartanalyzer..."
fails_analyzer="$(find lib test tools -name "*.dart" | xargs dartanalyzer --options .analysis_options)"
if [[ "$fails_analyzer" == *"[error]"* ]]; then
  echo "FAILED"
  echo "$fails_analyzer"
  exit 1
fi
echo "PASSED"

# Fast fail the script on failures.
set -e

# Run the tests.
pub run test
