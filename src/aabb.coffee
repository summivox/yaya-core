



# axis-aligned bounding box helpers
# aabb: {xMin, xMax, yMin, yMax} (in world frame)
module.exports =
  intersect: (a, b) ->
    if a.xMax < b.xMin || b.xMax < a.xMin then return false
    if a.yMax < b.yMin || b.yMax < a.yMin then return false
    return true