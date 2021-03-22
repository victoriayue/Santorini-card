defmodule SCARD.CLI do


  # json struct
  defmodule Json do
    defstruct [:players, :spaces, :turn]
  end

  defmodule Players do
    defstruct [:card, :tokens]
  end


  def encode_Map(map) do

    #json = Poison.encode!(map)
    {_, p_Value} = Map.fetch(map, :players)
    {_, s_Value} = Map.fetch(map, :spaces)
    {_, t_Value} = Map.fetch(map, :turn)

    p1 = Enum.at(p_Value, 0)
    p2 = Enum.at(p_Value, 1)
    {_, c1} = Map.fetch(p1, :card)
    c1 = Poison.encode!(c1)
    {_, t1} = Map.fetch(p1, :tokens)
    t1 = Poison.encode!(t1)
    {_, c2} = Map.fetch(p2, :card)
    c2 = Poison.encode!(c2)
    {_, t2} = Map.fetch(p2, :tokens)
    t2 = Poison.encode!(t2)

    # p_Value = Poison.encode!(p_Value)
    s_Value = Poison.encode!(s_Value)
    t_Value = Poison.encode!(t_Value)

    json = "{\"players\":[{\"card\": #{c1}, \"tokens\": #{t1}}, {\"card\": #{c2}, \"tokens\": #{t2}}],\"spaces\":#{s_Value},\"turn\":#{t_Value}}\n"
    json
  end
  @doc """
  send json to play-random. and get result json back
  """
  def send(json) do
    path = System.find_executable("win/play-random.exe")
    port = Port.open({:spawn, path}, [:binary])
    Port.command(port, json)

    receive do
      {^port, {:data, result}} ->
        result
    end
  end

  def show_board(json) do
    path = System.find_executable("win/gui.exe")
    port = Port.open({:spawn, path}, [:binary])
    Port.command(port, json)

    receive do
      {^port, {:data, result}} ->
        result
    end
  end

  def update(json) do
    regex = Regex.replace(~r/([a-z0-9+]):/, json, "\"\\1\":")
    json = regex |> String.replace("'", "\"") |> Poison.decode!

    players = json["players"]
    player1 = Enum.at(players, 0)
    player2 = Enum.at(players, 1)

    card1 = player1["card"]
    tokens1 = player1["tokens"]
    card2 = player2["card"]
    tokens2 = player2["tokens"]

    spaces = json["spaces"]
    turn = json["turn"]

    pmap1 = %{:card => card1, :tokens => tokens1}
    pla1 = struct(Players, pmap1)
    pmap2 = %{:card => card2, :tokens => tokens2}
    pla2 = struct(Players, pmap2)

    st = %{:players => [pmap1, pmap2], :spaces => spaces, :turn => turn}
    struct(Json, st)

  end

  @doc """
  check if the move isn't out of bound, or if it's too high/low to jump
  if it's vaid move, update player
  else, keep find recursive
  TODO if move block already have building or players
  """
  def valid_move(cpRow, cpCol, spaces, players, currentLevel) do
    # calculate valid moves
    valid = [[cpRow, cpCol+1], [cpRow, cpCol-1], [cpRow+1, cpCol], [cpRow-1, cpCol], [cpRow+1, cpCol+1], [cpRow-1, cpCol-1], [cpRow+1, cpCol-1], [cpRow-1, cpCol+1]]
    # pick rand move

    valid_move_recur(valid, spaces, players, currentLevel)
  end

  def valid_move_recur(valid, spaces, players, currentLevel) do
    if length(valid) == 0 do
      [-1, -1]
    else
      randMove = Enum.random(valid)
      r = Enum.at(randMove, 0)
      c = Enum.at(randMove, 1)
      build = Enum.at(Enum.at(spaces, r-1), c-1)
      # invalid case:
      # cell out of bound,
      # cell duplicate with other players
      # the level difference between current cell and target cell is more than one, player can't jump

      if (r <1 or r >5 or c <1 or c >5) or abs(build - currentLevel)>1 or ([r,c] in players) do
        valid = valid -- [randMove]
        valid_move_recur(valid, spaces, players, currentLevel)
      else
        [r,c]
      end
    end
  end

  @doc """
  check if the item is valid
  if it's out of bound
  or if the current cell already contain other build
  """
  def check_valid_neighbor(item, players) do
    cpRow = Enum.at(item, 0)
    cpCol = Enum.at(item, 1)

    if cpRow <1 or cpRow >5 or cpCol <1 or cpCol >5 or ([cpRow, cpCol] in players)do
      False
    else
      True
    end

  end


  def pick_rand_build(valid_neighbor, spaces, atlas) do
    # build random - default
    [r, c] = Enum.random(valid_neighbor)
    randLevel = Enum.at(Enum.at(spaces, r), c)

    # cannot build on a building level > 3
    if randLevel >=3 do
      valid_neighbor = valid_neighbor -- [r, c]
      pick_rand_build(valid_neighbor, spaces)
    if atlas == true do
      {[r,c], 4}
    else
      {[r,c], randLevel + 1}
    end
  end
  @doc """
  get all valid build position, try build valid

  """
  def valid_build(move, spaces, players, atlas) do
    cpRow = Enum.at(move, 0)
    cpCol = Enum.at(move, 1)
    valid = [[cpRow, cpCol+1], [cpRow, cpCol-1], [cpRow+1, cpCol], [cpRow-1, cpCol], [cpRow+1, cpCol+1], [cpRow-1, cpCol-1], [cpRow+1, cpCol-1], [cpRow-1, cpCol+1]]

    # get all valid neighbors
    valid_neighbor = []
    valid_neighbor = Enum.map(valid, fn item ->
      if check_valid_neighbor(item, players) do
        valid_neighbor ++ item
      end
    end)

    pick_rand_build(valid_neighbor, spaces, atlas)
    # update spaces

  end

  def pick_update_player(map) do
    """
    FIRST pick and update player
    check whether next_player is duplicate with current one
    check whether next_player contain un reachable build
    default pick first player
    """

    # pick player - default the first one
    {_, players} = Map.fetch(map, :players)
    {_, token1} = Map.fetch(Enum.at(players, 0), :tokens)
    {_, token2} = Map.fetch(Enum.at(players, 1), :tokens)
    [cpRow, cpCol] = Enum.at(token1, 0)

    # get current spaces
    {_, spaces} = Map.fetch(map, :spaces)
    # get building level on current cell.
    currentLevel = Enum.at(Enum.at(spaces, cpRow-1), cpCol-1)

    # get valid random move
    tokens = token1 ++ token2
    [r, c] = valid_move(cpRow, cpCol, spaces, tokens, currentLevel)

    # if no valid move for current player
    if [r,c] == [-1, -1] do
      # pick second player
      [cpRow, cpCol] = Enum.at(Enum.at(players, 0), 1)
      {_, spaces} = Map.fetch(map, :spaces)
      currentLevel = Enum.at(Enum.at(spaces, cpRow-1), cpCol-1)
      [r, c] = valid_move(cpRow, cpCol, spaces, tokens, currentLevel)
    end
    # when update to Map, need +1
    randMove = [r, c]

    # update players in map, opponent at front
    op = Enum.at(players, 1) # {"card":"Prometheus","tokens":[[2,3], [4.4]]}
    new_tokens = [randMove, Enum.at(token1, 1)]

    {_, card1} = Map.fetch(Enum.at(players, 0), :card)

    update = [op, %{:card => card1, :tokens => new_tokens}]

    # update map
    {_, map} = Map.get_and_update(map, :players, fn current ->
      {current, update}
    end)

    map
  end

  def update_build(map, atlas) do
    '''
    SECOND, build based on chosed player
    '''
    {_, players} = Map.fetch(map, :players)
    {_, token1} = Map.fetch(Enum.at(players, 0), :tokens)
    {_, token2} = Map.fetch(Enum.at(players, 1), :tokens)
    tokens = token1 ++ token2
    # build
    # build based on randMove

    # get a valid build option
    {[r,c], randLevel} = valid_build(randMove, spaces, tokens, atlas)

    # update spaces
    updateRow = Enum.at(spaces, r) |> List.replace_at(c, randLevel)
    spaces = List.replace_at(spaces, r, updateRow)
    {_, map} = Map.get_and_update(map, :spaces, fn current ->
      {current, spaces}
    end)


  end
  @doc """
  A token’s move can optionally swap places with an adjacent opponent token, as long as
  the token would be able to move to the opponent’s space if the opponent token were not there;
  otherwise, the move must be to an unoccupied space as usual.
  """
  def apollo(map) do
    IO.puts "apollo"


  end

  @doc """
  The moved token can optionally move a second time (i.e., the same token), as long as
  the first move doesn’t win, and as long as the second move doesn’t return to the original space.
  """
  def artemis(map) do
    IO.puts "artemis"

    # first, update player
    map = pick_update_player(map)

    # second, update build
    # update twice by default
    map = update_build(map, false)
    map = update_build(map, false)

    # last, update turn
    {_, map} = Map.get_and_update(map, :turn, fn current ->
      {current, current + 1}
    end)

    map
  end

  @doc """
  The build phase can build a space currently at level 0, 1, 2 to make it level 4,
  instead of building to exactly one more than the space’s current level.
  """
  def atlas(map) do
    IO.puts "atlas"

    # first, update player
    map = pick_update_player(map)

    # second, update build
    # make one build to level 4
    map = update_build(map, true)

    # last, update turn
    {_, map} = Map.get_and_update(map, :turn, fn current ->
      {current, current + 1}
    end)

    map
  end

  @doc """
  The moved token can optionally build a second time, but not on the same space
  as the first build within a turn.
  """
  def demeter(map) do
    IO.puts "demeter"

    # first, update player
    map = pick_update_player(map)

    # second, update build
    # update twice by default
    # TODO check first and second build not in same space
    map = update_build(map, false)
    map = update_build(map, false)

    # last, update turn
    {_, map} = Map.get_and_update(map, :turn, fn current ->
      {current, current + 1}
    end)

  end

  @doc """
  The moved token can optionally build a second time, but only on the same space
  as the first build within a turn, and only if the second build does not reach level 4.
  """
  def hephastus(map) do
    IO.puts "hephastus"

    # first, update player
    map = pick_update_player(map)

    # second, update build
    # update twice by default
    # TODO check first and second build are in same space
    map = update_build(map, false)
    map = update_build(map, false)

    # last, update turn
    {_, map} = Map.get_and_update(map, :turn, fn current ->
      {current, current + 1}
    end)
  end

  @doc """
  A token’s move can optionally enter the space of an opponent’s token, but only if
  the token can be pushed back to an unoccupied space, and only as long as the token
  would be able to move to the opponent’s space if the opponent token were not there.
  The unoccupied space where the opponent’s token is pushed can be at any level less than 4.
  Note that the opponent does not win by having a token forced to level 3; furthermore,
  such a token will have to move back down before it can move to level 3 for a win.
  """
  def minotaur(map) do
    IO.puts "hephastus"

    # first, update player
    map = pick_update_player(map)

    # second, update build
    map = update_build(map, false)

    # last, update turn
    {_, map} = Map.get_and_update(map, :turn, fn current ->
      {current, current + 1}
    end)
  end

  @doc """
  A token can win either by moving up to level 3 or by moving down two or more levels.
  (Moving down three levels is possible if a token was pushed by a Minotaur.)
  """
  def pan(map) do
    IO.puts "hephastus"

    # first, update player
    map = pick_update_player(map)

    # second, update build
    map = update_build(map, false)

    # last, update turn
    {_, map} = Map.get_and_update(map, :turn, fn current ->
      {current, current + 1}
    end)
  end

  @doc """
  A token can optionally build before moving, but then the move is constrained to
  the same level or lower (i.e., the level of the token’s new space can be no larger
  than the level of the token’s old space). The moved token must still build after moving.
  """
  def prometheus(map) do
    IO.puts "hephastus"

    # first, update player
    map = pick_update_player(map)

    # second, update build
    # update twice by default
    # TODO check first and second build are in same space
    map = update_build(map, false)

    # last, update turn
    {_, map} = Map.get_and_update(map, :turn, fn current ->
      {current, current + 1}
    end)
  end

  def calculate(map) do

    card = Map.fetch!(Enum.at(Map.fetch!(map, :players), 0), :card)
    cond do
      card == "Apollo" -> apollo(map)
      card == "Artemis" -> artemis(map)
      card == "Atlas" -> atlas(map)
      card == "Demeter" -> demeter(map)
      card == "Hephastus" -> hephastus(map)
      card == "Minotaur" -> minotaur(map)
      card == "Pan" -> pan(map)
      card == "Prometheus" -> prometheus(map)
    end

  end

  def check_win(map) do
    {_, players} = Map.fetch(map, :players)
    p1 = Enum.at(players, 0)
    p2 = Enum.at(players, 1)
    {_, token1} = Map.fetch(p1, :tokens)
    {_, token2} = Map.fetch(p2, :tokens)

    {_, spaces} = Map.fetch(map, :spaces)

    # if player stand on a building with 3 level, win
    [p1row, p1col] = Enum.at(token1, 0)
    level1 = Enum.at(Enum.at(spaces, p1row-1), p1col-1)

    [p2row, p2col] = Enum.at(token1, 1)
    level2 = Enum.at(Enum.at(spaces, p2row-1), p2col-1)
    if level1 == 3 or level2 == 3 do
      IO.puts "I'm win\n"
      true
    end

    [p3row, p3col] = Enum.at(token2, 0)
    level3 = Enum.at(Enum.at(spaces, p3row-1), p3col-1)

    [p4row, p4col] = Enum.at(token2, 1)
    level4 = Enum.at(Enum.at(spaces, p4row-1), p4col-1)
    if level3 == 3 or level4 == 3 do
      IO.puts "You're win\n"
      true
    end
    false

  end

  def main(_args \\ []) do

    oppo = IO.gets "Your turn: \n"

    cond do
      # when start the game, pick two cards
      oppo == "\n" ->
        oppo = ~S"""
         [{"card":"Artemis"},{"card":"Prometheus"}]
         """
        # json = encode_Map(oppo)
        IO.puts oppo
        main()

      # otherwise, pick tokens
      String.first(oppo) == "[" ->
        {_, dec} = Poison.decode(oppo)
        cur = Enum.at(dec, 0)
        {_, cur_card} = Poison.encode(cur["card"])

        another = Enum.at(dec, 1)
        {_, ano_card} = Poison.encode(another["card"])
        {_, ano_token} = Poison.encode(another["tokens"])

        s_Value = "[[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0]]"
        t_Value = 1
        # TODO check whether the token is duplicate
        players = "[{\"card\":#{ano_card},\"tokens\":#{ano_token}}, {\"card\":#{cur_card},\"tokens\":[[2,3], [4,4]]}]"
        json = "{\"players\":#{players},\"spaces\":#{s_Value},\"turn\":#{t_Value}}\n"
        IO.puts json
        main()

      # else, compute next move
      true ->
      # receive, update moves, create struct
      map = update(oppo)
      # calculate next move
      result = calculate(map)
      json = encode_Map(result)
      IO.puts json
      # check win
      if not check_win(map) do
        # keep playing
        main()
      end

    end

  end

end
