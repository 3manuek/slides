# Nerdearla España 2025

Generate the charts:

```bash
cd charts/
make all
```

Serve slides:

```bash
npx @marp-team/marp-cli -s .   --html --allow-local-files --port 3000
```

```bash
marp --html -w -s --allow-local-files .
```

To export the slides to PDF:

```bash
marp pg_prod_eco.md --allow-local-files --pdf
```

or with npx:

```bash
npx @marp-team/marp-cli pg_prod_eco.md --theme-set ./themes --html --allow-local-files --pdf
```

