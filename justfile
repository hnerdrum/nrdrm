[private]
default:
    @just --list

db cmd:
    #!/usr/bin/env bash
    set -euo pipefail
    file="{{ justfile_directory() }}/docker-databases.yml"
    case "{{ cmd }}" in
      up) docker compose -f "$file" up -d ;;
      down) docker compose -f "$file" down ;;
      reset)
        docker compose -f "$file" down -v
        docker compose -f "$file" up -d
        ;;
      *)
        echo "usage: just db up|down|reset" >&2
        exit 1
        ;;
    esac

recipes *args:
    @just fwd server/recipes {{ args }}

identity *args:
    @just fwd server/identity {{ args }}

gateway *args:
    @just fwd server/gateway {{ args }}

uno *args:
    @just fwd server/uno {{ args }}

web-recipes *args:
    @just fwd web/recipes {{ args }}

web-uno *args:
    @just fwd web/uno {{ args }}

home *args:
    @just fwd web/home {{ args }}

wedding *args:
    @just fwd web/wedding {{ args }}

delete-images *args:
    @just fwd cron/delete-container-images {{ args }}

[private]
fwd dir *args:
    @just --justfile "{{ justfile_directory() }}/{{ dir }}/justfile" --working-directory "{{ justfile_directory() }}/{{ dir }}" {{ args }}
