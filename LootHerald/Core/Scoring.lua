-- Loot Herald: pure scoring math (no game API calls, unit-tested).
local _, ns = ...

local Scoring = {}
ns.Scoring = Scoring

local EPSILON = 0.0001

-- score = sum(stat value x weight)
function Scoring.Score(stats, weights)
    if not stats or not weights then return 0 end
    local total = 0
    for stat, value in pairs(stats) do
        local w = weights[stat]
        if w and type(value) == "number" then
            total = total + value * w
        end
    end
    return total
end

-- Returns the per-stat breakdown sorted by contribution (for /lh debug).
function Scoring.Breakdown(stats, weights)
    local rows = {}
    for stat, value in pairs(stats or {}) do
        local w = (weights and weights[stat]) or 0
        rows[#rows + 1] = { stat = stat, value = value, weight = w, points = value * w }
    end
    table.sort(rows, function(a, b)
        if a.points == b.points then return a.stat < b.stat end
        return a.points > b.points
    end)
    return rows
end

-- Percent change from the equipped score to the new score.
-- Second return is true when there is no baseline (empty slot or an equipped
-- item that is worth nothing to this role).
function Scoring.PercentChange(newScore, oldScore)
    if (oldScore or 0) <= EPSILON then
        if (newScore or 0) > EPSILON then return 100, true end
        return 0, true
    end
    return (newScore - oldScore) / oldScore * 100, false
end

-- UPGRADE   pct >= threshold (or anything useful in an empty/worthless slot)
-- EQUAL     within +/- threshold
-- DOWNGRADE below -threshold
-- NONE      the new item is worth nothing to this role
function Scoring.Classify(pct, threshold, noBaseline, newScore)
    if (newScore or 0) <= EPSILON then return "NONE" end
    if noBaseline then return "UPGRADE" end
    if pct >= threshold then return "UPGRADE" end
    if pct > -threshold then return "EQUAL" end
    return "DOWNGRADE"
end

-- Add stat tables together (used to combine main hand + off hand).
function Scoring.AddStats(into, stats)
    for k, v in pairs(stats or {}) do into[k] = (into[k] or 0) + v end
    return into
end

-- Hit beyond the cap is worth nothing. `baseHit` is the hit you'd have
-- without the item(s) in question. Returns a copy of stats and whether the
-- item's hit was reduced.
function Scoring.ApplyHitCap(stats, baseHit, cap)
    if not stats or not stats.HIT or not cap then return stats, false end
    local room = math.max(0, cap - (baseHit or 0))
    if stats.HIT <= room then return stats, false end
    local out = {}
    for k, v in pairs(stats) do out[k] = v end
    out.HIT = room
    return out, true
end

-- The stats that changed and matter to this role, biggest effect first.
-- Each row: { stat, delta, points }.
function Scoring.StatDiff(newStats, oldStats, weights)
    local rows, seen = {}, {}
    local function add(stat)
        if seen[stat] then return end
        seen[stat] = true
        local delta = ((newStats and newStats[stat]) or 0) - ((oldStats and oldStats[stat]) or 0)
        local w = (weights and weights[stat]) or 0
        if math.abs(delta) > 0.001 and w ~= 0 then
            rows[#rows + 1] = { stat = stat, delta = delta, points = delta * w }
        end
    end
    for stat in pairs(newStats or {}) do add(stat) end
    for stat in pairs(oldStats or {}) do add(stat) end
    table.sort(rows, function(a, b)
        if math.abs(a.points) == math.abs(b.points) then return a.stat < b.stat end
        return math.abs(a.points) > math.abs(b.points)
    end)
    return rows
end

-- How much a role values an item compared with the role that values each of
-- its stats the most (0..1). Used to guess who else in the group wants it.
function Scoring.Share(stats, weights, maxWeights)
    local denom = Scoring.Score(stats, maxWeights)
    if denom <= EPSILON then return 0 end
    return Scoring.Score(stats, weights) / denom
end

-- Merge the user's custom weights on top of a profile's built-in weights.
function Scoring.MergeWeights(base, overrides)
    local out = {}
    for k, v in pairs(base or {}) do out[k] = v end
    for k, v in pairs(overrides or {}) do out[k] = v end
    return out
end
