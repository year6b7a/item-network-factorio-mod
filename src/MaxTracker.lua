local M = {}

function M.new(period)
  return {
    period = period,
  }
end

function M.get_max(tracker)
  if tracker.max0 == nil then
    return nil
  end

  if tracker.max1 == nil then
    return tracker.max0
  end

  return math.max(tracker.max0, tracker.max1)
end

function M.update(tracker, amount, tick)
  if tracker.tick == nil then
    tracker.tick = tick
    tracker.max0 = amount
  elseif tick < tracker.tick + tracker.period * 0.5 then
    tracker.max0 = math.max(tracker.max0, amount)
  elseif tick < tracker.tick + tracker.period * 1.5 then
    tracker.max0 = math.max(tracker.max0, amount)
    if tick >= tracker.tick + tracker.period then
      -- shift
      tracker.max0 = tracker.max1
      tracker.max1 = amount
      tracker.tick = tracker.tick + tracker.period * 0.5
    elseif tracker.max1 == nil then
      tracker.max1 = amount
    else
      tracker.max1 = math.max(tracker.max1, amount)
    end
  else
    tracker.tick = tick
    tracker.max0 = amount
    tracker.max1 = nil
  end
end

return M
