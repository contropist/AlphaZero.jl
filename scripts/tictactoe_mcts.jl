################################################################################
# Solving simple tic tac toe with MCTS
################################################################################

using AlphaZero.MCTS

using Gobblet.TicTacToe

################################################################################

const PROFILE = false
const INTERACTIVE = true

const INITIAL_TRAINING = 1. # second
const TIMEOUT = 0.5 # seconds

################################################################################
  
MCTS.white_playing(s::State) = s.curplayer == Red

MCTS.board(s::State) = copy(s.board)

MCTS.board_symmetric(s::State) = map!(symmetric, similar(s.board), s.board)

MCTS.play!(s::State, a) = execute_action!(s, a)

MCTS.undo!(s::State, a) = cancel_action!(s, a)

function MCTS.white_reward(s::State) :: Union{Nothing, Float64}
  s.finished || return nothing
  isnothing(s.winner) && return 0
  s.winner == Red && return 1
  return -1
end

function MCTS.available_actions(s::State)
  actions = Action[]
  sizehint!(actions, NUM_POSITIONS)
  fold_actions(s, actions) do actions, a
    push!(actions, a)
  end
  return actions
end

################################################################################
# Write the evaluator

struct RolloutEvaluator end

function rollout(board)
  state = State(copy(board), first_player=Red)
  while true
    reward = MCTS.white_reward(state)
    isnothing(reward) || (return reward)
    action = rand(MCTS.available_actions(state))
    MCTS.play!(state, action)
   end
end

function MCTS.evaluate(::RolloutEvaluator, board, available_actions)
  V = rollout(board)
  n = length(available_actions)
  P = [1 / n for a in available_actions]
  return P, V
end

################################################################################

const GobbletMCTS = MCTS.Env{State, Board, Action, RolloutEvaluator}

struct MonteCarloAI <: AI
  env :: GobbletMCTS
  timeout :: Float64
end

import Gobblet.TicTacToe: play

function play(ai::MonteCarloAI, state)
  MCTS.set_root!(ai.env, state)
  MCTS.explore!(ai.env, ai.timeout)
  actions, distr = MCTS.policy(ai.env)
  actions[argmax(distr)]
end

################################################################################

function debug_tree(env; k=10)
  pairs = collect(env.tree)
  k = min(k, length(pairs))
  most_visited = sort(pairs, by=(x->x.second.Ntot), rev=true)[1:k]
  for (b, info) in most_visited
    println("N: ", info.Ntot)
    print_board(State(b))
  end
end

################################################################################

# In our experiments, we can simulate ~10000 games per second

using Profile
using ProfileView

if PROFILE
  env = GobbletMCTS(RolloutEvaluator())
  MCTS.explore!(env, 0.1)
  Profile.clear()
  @profile MCTS.explore!(env, 2.0)
  ProfileView.svgwrite("profile_mcts.svg")
  # To examine code:
  # code_warntype(MCTS.select!, Tuple{GobbletMCTS})
end

env = GobbletMCTS(RolloutEvaluator())
state = State()
MCTS.set_root!(env, state)
MCTS.explore!(env, INITIAL_TRAINING)

if INTERACTIVE
  interactive!(state, red=MonteCarloAI(env, TIMEOUT), blue=Human())
end

################################################################################
