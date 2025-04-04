function buildSanFlags --argument SRCDIR
    # Clear sanitizers options
    set -e ASAN_OPTIONS
    set -e LSAN_OPTIONS
    set -e UBSAN_OPTIONS
    set -e TSAN_OPTIONS
    # Enable full SAN mode
    # This also has to be in runRTAtest.fish
    if not test -z "$SAN"; and test "$SAN" = "On"
      compiler_libraries "$COMPILER_VERSION"
      echo "Use SAN mode: $SAN_MODE"
      set common_options "log_exe_name=true:external_symbolizer_path=$INNERWORKDIR/ArangoDB/utils/llvm-symbolizer-client.py"
      set -xg ARCHER_OPTIONS verbose=1
      set -xg OMP_TOOL_LIBRARIES "$COMPILER_LIB_DIR/libarcher.so"
      switch "$SAN_MODE"
        case "AULSan"
          # address sanitizer
          set -xg ASAN_OPTIONS "$common_options:log_path=$INNERWORKDIR/aulsan.log:handle_ioctl=true:check_initialization_order=true:detect_container_overflow=true:detect_stack_use_after_return=false:detect_odr_violation=1:strict_init_order=true"

          # leak sanitizer
          set -xg LSAN_OPTIONS "$common_options:log_path=$INNERWORKDIR/aulsan.log"

          # undefined behavior sanitizer
          set -xg UBSAN_OPTIONS "$common_options:log_path=$INNERWORKDIR/aulsan.log:print_stacktrace=1"

          # suppressions
          if test -f "$SRCDIR/asan_arangodb_suppressions.txt"
            set -xg ASAN_OPTIONS "$ASAN_OPTIONS:suppressions=$INNERWORKDIR/ArangoDB/asan_arangodb_suppressions.txt:print_suppressions=0"
          end

          if test -f "$SRCDIR/lsan_arangodb_suppressions.txt"
            set -xg LSAN_OPTIONS "$LSAN_OPTIONS:suppressions=$INNERWORKDIR/ArangoDB/lsan_arangodb_suppressions.txt:print_suppressions=0"
          end

          if test -f "$SRCDIR/ubsan_arangodb_suppressions.txt"
            set -xg UBSAN_OPTIONS "$UBSAN_OPTIONS:suppressions=$INNERWORKDIR/ArangoDB/ubsan_arangodb_suppressions.txt:print_suppressions=0"
          end

          echo "ASAN: $ASAN_OPTIONS"
          echo "LSAN: $LSAN_OPTIONS"
          echo "UBSAN: $UBSAN_OPTIONS"
        case "TSan"
          # thread sanitizer
          set -xg TSAN_OPTIONS "$common_options:log_path=$INNERWORKDIR/tsan.log:detect_deadlocks=true:second_deadlock_stack=1"

          # suppressions
          if test -f "$SRCDIR/tsan_arangodb_suppressions.txt"
            set -xg TSAN_OPTIONS "$TSAN_OPTIONS:suppressions=$INNERWORKDIR/ArangoDB/tsan_arangodb_suppressions.txt:print_suppressions=0:ignore_noninstrumented_modules=1"
          end

          echo "TSAN: $TSAN_OPTIONS"
        case '*'
          echo "Unknown sanitizer mode: $SAN_MODE"
      end
    else
      echo "Don't use SAN mode"
    end
end

