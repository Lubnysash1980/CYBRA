[1m=== CYBRA BRANCH LOAD MONITOR V2 ===[0m
Time: 2026-06-08T12:56:30
Redis: [92mOK[0m
Git branch: main dirty (3310)

[1mLEGEND[0m
[91mчервоне = невиконане / pending / returned[0m
[92mзелене = виконується / process active[0m
[90mнейтральне = виконане / done[0m

[1mSUMMARY[0m
Невиконане pending: [91m(3)[0m
Виконується running: [92m(1)[0m
Виконане done: [90m(5)[0m
Повернуте return: [91m(5)[0m
Аудит audit: [93m(4)[0m
Процеси йдуть: [92m(1)[0m
Процеси не йдуть/відсутні: [91m(5)[0m

[1mBRANCHES / ГІЛКИ[0m

[1mFINANCE / фінансові задачі[0m
  статус: [91mНЕВИКОНАНЕ[0m
  навантаження: [91m(100%)[0m
  невиконане: [91m(3)[0m | виконується: [92m(0)[0m | виконане: [90m(3)[0m
  return: [91m(3)[0m | audit: [93m(4)[0m
  процеси йдуть: [92m(0)[0m | не йдуть: [91m(1)[0m | очікувано: (1)
  storage files: (5)
  queues:
    pending cybra:finance:evolution:pool: [91m(3)[0m
    pending cybra_finance_evolution: [91m(0)[0m
    running cybra:branch:finance:running: [92m(0)[0m
    done cybra:branch:finance:done: [90m(1)[0m
    done cybra:completed:ai_tasks: [90m(2)[0m

[1mMETA EVOLUTION / еволюція[0m
  статус: [91mНЕВИКОНАНЕ[0m
  навантаження: [93m(50%)[0m
  невиконане: [91m(0)[0m | виконується: [92m(0)[0m | виконане: [90m(2)[0m
  return: [91m(2)[0m | audit: [93m(0)[0m
  процеси йдуть: [92m(0)[0m | не йдуть: [91m(1)[0m | очікувано: (1)
  storage files: (175)
  queues:
    pending cybra:meta:evolution:pool: [91m(0)[0m
    running cybra:branch:meta:running: [92m(0)[0m
    done cybra:branch:meta:done: [90m(0)[0m
    done cybra:completed:ai_tasks: [90m(2)[0m

[1mKIBRA POOLS / монета і пули[0m
  статус: [92mВИКОНУЄТЬСЯ[0m
  навантаження: [92m(6%)[0m
  невиконане: [91m(0)[0m | виконується: [92m(1)[0m | виконане: [90m(0)[0m
  return: [91m(0)[0m | audit: [93m(0)[0m
  процеси йдуть: [92m(1)[0m | не йдуть: [91m(0)[0m | очікувано: (1)
  storage files: (251)
  queues:
    pending cybra:kibra:pool:mining_blocks: [91m(0)[0m
    pending cybra:ai:tasks:block_inbox: [91m(0)[0m
    pending ai_block_inbox: [91m(0)[0m
    running cybra:branch:kibra:running: [92m(0)[0m
    done cybra:branch:kibra:done: [90m(0)[0m

[1mIT STRUCTURE / структура[0m
  статус: [93mНЕЙТРАЛЬНО[0m
  навантаження: [92m(20%)[0m
  невиконане: [91m(0)[0m | виконується: [92m(0)[0m | виконане: [90m(0)[0m
  return: [91m(0)[0m | audit: [93m(0)[0m
  процеси йдуть: [92m(0)[0m | не йдуть: [91m(1)[0m | очікувано: (1)
  storage files: (7)
  queues:
    pending it_department: [91m(0)[0m
    pending cybra_mgs_all: [91m(0)[0m
    running cybra:branch:structure:running: [92m(0)[0m
    done cybra:branch:structure:done: [90m(0)[0m

[1mORACLE / CODESPACE[0m
  статус: [93mНЕЙТРАЛЬНО[0m
  навантаження: [92m(20%)[0m
  невиконане: [91m(0)[0m | виконується: [92m(0)[0m | виконане: [90m(0)[0m
  return: [91m(0)[0m | audit: [93m(0)[0m
  процеси йдуть: [92m(0)[0m | не йдуть: [91m(1)[0m | очікувано: (1)
  storage files: (35)
  queues:
    pending cybra_oracle_tasks: [91m(0)[0m
    pending cybra_codespace_inbox: [91m(0)[0m
    running cybra:branch:oracle:running: [92m(0)[0m
    done cybra:branch:oracle:done: [90m(0)[0m

[1mCYBER PARLIAMENT / парламент[0m
  статус: [93mНЕЙТРАЛЬНО[0m
  навантаження: [92m(20%)[0m
  невиконане: [91m(0)[0m | виконується: [92m(0)[0m | виконане: [90m(0)[0m
  return: [91m(0)[0m | audit: [93m(0)[0m
  процеси йдуть: [92m(0)[0m | не йдуть: [91m(1)[0m | очікувано: (1)
  storage files: (306)
  queues:
    pending parliament_inbox: [91m(0)[0m
    running cybra:branch:parliament:running: [92m(0)[0m
    done cybra:branch:parliament:done: [90m(0)[0m

[1mACTIONS / ДІЇ[0m
  cybra-load audit finance
  cybra-load return finance
  cybra-load done finance
  cybra-load rebalance finance
  cybra-load serve 8796