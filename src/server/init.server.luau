-- uppercase = white, lowercase = black
-- enpassant, checks, and checkmate checks
-- use fen notation for stockfish
local chessGamePosition = {
    {"R", "N", "B", "Q", "K", "B", "N", "R"}, -- row 1 (black)
    {"P", "P", "P", "P", "P", "P", "P", "P"}, -- row 2 (black pawns)
    {"", "", "", "", "", "", "", ""},         -- row 3 (empty)
    {"", "", "", "", "", "", "", ""},         -- row 4 (empty)
    {"", "", "", "", "", "", "", ""},         -- row 5 (empty)
    {"", "", "", "", "", "", "", ""},         -- row 6 (empty)
    {"p", "p", "p", "p", "p", "p", "p", "p"}, -- row 7 (white pawns)
    {"r", "n", "b", "q", "k", "b", "n", "r"}  -- row 8 (white)
}

local chessGameinfo = {
    ["nextPlayer"] = "w",
    ["enPassantCoordinates"] = "-",
    ["movesSinceCapture"] = "0",
    ["moveNumber"] = 1,
    ["kingMovedWhite"] = false,
    ["kingMovedBlack"] = false,
    ["rookMovedWhiteA"] = false,
    ["rookMovedWhiteH"] = false,
    ["rookMovedBlackA"] = false,
    ["rookMovedBlackH"] = false
}

local function isMoveValid(startRow, startCollumn, endRow, endCollumn)
    local startPiece = chessGamePosition[startRow][startCollumn]
    local endPiece = chessGamePosition[endRow][endCollumn]

    local isCurrentPieceWhite = startPiece == startPiece:lower()
    local isEnemyPieceWhite = endPiece == endPiece:lower()

    local function areCoordinatesInBounds(startR, startC, endR, endC)
        local maxRow, maxCol = #chessGamePosition, #chessGamePosition[1]
        return startR >= 1 and startR <= maxRow and startC >= 1 and startC <= maxCol and
               endR >= 1 and endR <= maxRow and endC >= 1 and endC <= maxCol
    end

    local function isEnemySquare(row, col)
        return isCurrentPieceWhite == isEnemyPieceWhite
    end

    local function isEmptySquare(row, col)
        return endPiece == ""
    end

    local function isCapturableSquare(row, col)
        return isEmptySquare(row, col) or isEnemySquare(row, col)
    end

    -- as we only check the squares betwene the start and end squares, and as the last piece is already known to be capturable
    -- there is no need to check this again
    local function pathCheck(startR, startC, endR, endC)
        local rowIncrement = startR == endR and 0 or (endR > startR and 1 or -1)
        local colIncrement = startC == endC and 0 or (endC > startC and 1 or -1)
        local r, c = startR + rowIncrement, startC + colIncrement

        while r ~= endR or c ~= endC do
            if chessGamePosition[r][c] ~= "" then
                return false
            end
            r = r + rowIncrement
            c = c + colIncrement
        end

        return true
    end

    -- is in bounds, is capturable (ie. no friendly pieces), have moved 1 square
    if areCoordinatesInBounds(startRow, startCollumn, endRow, endCollumn) and isCapturableSquare(endRow, endCollumn) and (startRow == endRow and startCollumn == endCollumn)  then
        if startPiece:lower() == "p" then
            local forwardDirection = isCurrentPieceWhite and -1 or 1
            local startRowForDoubleMove = isCurrentPieceWhite and 7 or 2

            if endCollumn == startCollumn then
                -- one square move
                if endRow == startRow + forwardDirection and isEmptySquare(endRow, endCollumn) then
                    return true
                end

                -- two square
                if endRow == startRow + 2 * forwardDirection and startRow == startRowForDoubleMove then
                    if isEmptySquare(startRow + forwardDirection, startCollumn) and isEmptySquare(endRow, endCollumn) then
                        return true
                    end
                end
                
                -- capture moves
            elseif endCollumn == startCollumn + 1 or endCollumn == startCollumn - 1 then
                if endRow == startRow + forwardDirection and
                isEnemySquare(endRow, endCollumn) then
                    return true
                end
            end
        end

        -- king moves
        if startPiece:lower() == "k" then
            local rowDiff = math.abs(endRow - startRow)
            local colDiff = math.abs(endCollumn - startCollumn)

            if (rowDiff <= 1 and colDiff <= 1) then
                return true
            end
        end

        -- rook moves
        if startPiece:lower() == "r" then
            if startRow == endRow or startCollumn == endCollumn then
                return pathCheck(startRow, startCollumn, endRow, endCollumn)
            end
        end
        
    end
end