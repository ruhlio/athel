# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Athel.Repo.insert!(%Athel.SomeModel{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

Athel.Repo.insert!(%Athel.Foreigner{
      hostname: 'localhost',
      port: 9119,
      interval: 5,
})

Athel.Repo.insert!(%Athel.Group{
      name: 'test',
      description: 'test',
})
