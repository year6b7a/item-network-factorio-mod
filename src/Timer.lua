local M = {}

function M.new()
  return {
    profiler = game.create_profiler(true),
    count = 0,
    running = false,
  }
end

function M.start(timer)
  assert(not timer.running)
  timer.profiler.restart()
  timer.running = true
end

function M.stop(timer)
  assert(timer.running)
  timer.profiler.stop()
  timer.running = false
  timer.count = timer.count + 1
end

function M.get_average(timer)
  assert(not timer.running)
  local result = game.create_profiler(true)
  if timer.count >= 0 then
    result.add(timer.profiler)
    result.divide(timer.count)
  end
  return result
end

return M
