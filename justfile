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
    @just web-recipes env
    @just delete-images env
    @just agents env
    @just training env
    @just web-training env

recipes *args:
    @just fwd server/recipes {{ args }}

identity *args:
    @just fwd server/identity {{ args }}

gateway *args:
    @just fwd server/gateway {{ args }}

web-recipes *args:
    @just fwd web/recipes {{ args }}

home *args:
    @just fwd web/home {{ args }}

delete-images *args:
    @just fwd cron/delete-container-images {{ args }}

agents *args:
    @just fwd server/agents {{ args }}

training *args:
    @just fwd server/training {{ args }}

web-training *args:
    @just fwd web/training {{ args }}

[private]
fwd dir *args:
    @just --justfile "{{ justfile_directory() }}/{{ dir }}/justfile" --working-directory "{{ justfile_directory() }}/{{ dir }}" {{ args }}
