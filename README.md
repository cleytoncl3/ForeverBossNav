# Forever Boss Nav

Addon para **World of Warcraft: Forever** (cliente 1.60.1, interface `16001`).

Quando você entra numa dungeon ou raid, abre uma janela com:

- **Todos os bosses da instância na ordem do cliente**, separados por ala (Monastério Escarlate, Gládio Cruel, Pico da Rocha Negra, Stratholme).
- **Próximo boss** destacado, com uma seta no topo.
- **Kills automáticos**: detecta pelo `ENCOUNTER_END` / `BOSS_KILL` e pela morte do NPC no combat log (pelo ID do NPC, então funciona em cliente pt-BR).
- **Aprende sozinho** bosses de dungeons novas: o primeiro pull de um boss desconhecido o adiciona à lista e fica salvo.
- **Nomes localizados**: quando você mira um boss, o nome em português passa a aparecer junto do nome em inglês.

## Cobertura

45 instâncias e 300 bosses, lidos do cliente do WoW Forever (via [wowforevertalents.com](https://wowforevertalents.com/dungeons/)):

- Todas as dungeons clássicas (Ragefire até Scholomance), com as listas de bosses alteradas no Forever.
- Dungeons novas com bosses já no cliente: **The Hall of Thanes, Ruins of Lordaeron, Excavation Site: Wetlands, City of Dalaran**.
- Dungeons anunciadas mas ainda sem dados no cliente: **The Drowned City, Krol'dor Stronghold, Alcaz Prison, Blackmaw Hold, Shaper's Terrace** (bosses aprendidos em jogo).
- Raids: Onyxia, MC, BWL, ZG, AQ20, AQ40, Naxx, além das que ainda estão no cliente (Nightmare Grove, Scarlet Enclave, etc.) e das anunciadas (Barrow Deeps, Hyjal Summit).

## Sobre a seta e as coordenadas (importante)

Desde o patch 7.1, a Blizzard **bloqueia** `UnitPosition()` e `GetPlayerFacing()` dentro de instâncias, e o cliente Classic/Forever herdou esse bloqueio. O Forever também não tem mapa de dungeon para o addon ler. Na prática, **nenhum addon consegue saber onde você está dentro de uma dungeon**, então não dá para calcular direção nem distância até um boss.

O que o addon faz:

- **Modo normal (sempre funciona):** a seta amarela marca o **próximo boss na ordem**.
- **Modo navegação (só se o cliente liberar posição):** se `UnitPosition` devolver coordenadas, a seta gira e aponta para o **boss vivo mais próximo**, mostrando a distância em metros. As posições são gravadas automaticamente no pull de cada boss, ou com `Shift+clique` no boss / `/fbn mark`.

## Comandos

| Comando | O que faz |
| --- | --- |
| `/fbn` | Mostra/esconde a janela |
| `/fbn list` | Lista todas as dungeons e raids por nível |
| `/fbn show <nome>` | Mostra os bosses de uma instância fora dela (ex.: `/fbn show dire`) |
| `/fbn reset` | Zera os kills da instância atual |
| `/fbn mark` | Grava sua posição como local do alvo ou do próximo boss |
| `/fbn lock` | Trava/destrava a janela |

Na lista: **clique** marca/desmarca um boss como morto; **Shift+clique** grava a posição.

## Instalação

1. Baixe o repositório (Code → Download ZIP).
2. Extraia a pasta `ForeverBossNav` para `Interface\AddOns\` dentro da pasta do cliente Forever (em `World of Warcraft\`, a subpasta do Forever — a mesma onde ficam os outros addons dele).
3. Na tela de personagens, em AddOns, confirme que **Forever Boss Nav** está ativo.

## Atualizar os dados

`tools/gen.js` gera o `Data.lua` a partir das páginas de instância do wowforevertalents.com salvas em `raw/<slug>.html` e de um `bosses2.json` com o ID de mapa de cada uma. Rode `node tools/gen.js Data.lua` na pasta onde estão esses arquivos.

## Licença

MIT, veja [LICENSE](LICENSE).
