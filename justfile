[private]
default:
    @just --list

db cmd:
    #!/usr/bin/env bash
    set -euo pipefail
    file="{{ justfile_directory() }}/docker-databases.yml"
    case "{{ cmd }}" in
      up) docker compose -f "$file" up -d --wait ;;
      down) docker compose -f "$file" down ;;
      reset)
        docker compose -f "$file" down -v
        docker compose -f "$file" up -d --wait
        ;;
      *)
        echo "usage: just db up|down|reset" >&2
        exit 1
        ;;
    esac

env:
    @just recipes env
    @just identity env
    @just gateway env
    @just uno env
    @just web-recipes env
    @just web-uno env
    @just delete-images env
    @just agents env

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

delete-images *args:
    @just fwd cron/delete-container-images {{ args }}

agents *args:
    @just fwd server/agents {{ args }}

[private]
fwd dir *args:
    @just --justfile "{{ justfile_directory() }}/{{ dir }}/justfile" --working-directory "{{ justfile_directory() }}/{{ dir }}" {{ args }}
