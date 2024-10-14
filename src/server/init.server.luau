-- hobby project for soph. programming/chess club

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- uppercase = white, lowercase = black
-- enpassant, checks, and checkmate checks
-- fen notation for stockfish
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

local function pieceIsWhite(piece)
    return piece == piece:lower()
end

-- square is 4x4 studs, 64 squares, alternating white and black
local function createBoardFromPosition(position)
    local board = workspace.Board
    local boardPieces = board.pieces

    for _, oldPiece in board:GetDescendants() do
        oldPiece:Destroy()
    end

    for rowIndex, row in ipairs(chessGamePosition) do
        for collumnIndex, piece in ipairs(row) do
            -- get piece from lowercase ident.
            local pieceMesh = ReplicatedStorage.Pieces[piece:lower()]:Clone()

            if pieceIsWhite(piece) then
                pieceMesh.BrickColor = BrickColor.new("Institutional white")
            else
                pieceMesh.BrickColor = BrickColor.new("Really black")
            end

            pieceMesh.Position = board[rowIndex][collumnIndex].CFrame * CFrame.new(Vector3.new(0, 1, 0))
            pieceMesh.Parent = board.Pieces
        end
    end
end

local function isMoveValid(startRow, startCollumn, endRow, endCollumn)
    local startPiece = chessGamePosition[startRow][startCollumn]
    local endPiece = chessGamePosition[endRow][endCollumn]
    local isCurrentPieceWhite = pieceIsWhite(startPiece)
    local isEnemyPieceWhite = pieceIsWhite(endPiece)

    -- no fake pieces
    if startPiece == "" then
        return false
    end

    -- within 8x8 grid
    local function areCoordinatesInBounds(startR, startC, endR, endC)
        local maxRow, maxCol = #chessGamePosition, #chessGamePosition[1]
        return startR >= 1 and startR <= maxRow and startC >= 1 and startC <= maxCol and
               endR >= 1 and endR <= maxRow and endC >= 1 and endC <= maxCol
    end

    local function isEmptySquare(row, col)
        return chessGamePosition[row][col] == ""
    end

    -- is opp. color
    local function isEnemySquare(row, col)
        if isEmptySquare(row, col) then
            return false
        end

        return isCurrentPieceWhite ~= isEnemyPieceWhite
    end

    local function isCapturableSquare(row, col)
        return isEmptySquare(row, col) or isEnemySquare(row, col)
    end

    -- as i only check the squares between the start and end squares, and as the last piece is already known to be capturable
    -- there is no need to check this again
    local function pathCheck(startR, startC, endR, endC)
        local rowIncrement = startR == endR and 0 or (endR > startR and 1 or -1)
        local colIncrement = startC == endC and 0 or (endC > startC and 1 or -1)
        local r, c = startR + rowIncrement, startC + colIncrement

        -- iter through pieces path, check for pieces blocking it
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
    -- why was it == before lol
    if areCoordinatesInBounds(startRow, startCollumn, endRow, endCollumn) and isCapturableSquare(endRow, endCollumn) and (startRow ~= endRow and startCollumn ~= endCollumn)  then
        if startPiece:lower() == "p" then
            local forwardDirection = isCurrentPieceWhite and -1 or 1
            local startRowForDoubleMove = isCurrentPieceWhite and 7 or 2

            if endCollumn == startCollumn then
                -- one square move
                if (endRow == startRow + forwardDirection) and isEmptySquare(endRow, endCollumn) then
                    return true
                end

                -- two square
                if (endRow == startRow + 2 * forwardDirection) and (startRow == startRowForDoubleMove) then
                    if isEmptySquare(startRow + forwardDirection, startCollumn) and isEmptySquare(endRow, endCollumn) then
                        return true
                    end
                end
                
                -- capture moves
            elseif (endCollumn == startCollumn + 1) or (endCollumn == startCollumn - 1) then
                if (endRow == startRow + forwardDirection) and isEnemySquare(endRow, endCollumn) then
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
            if (startRow == endRow) or (startCollumn == endCollumn) then
                return pathCheck(startRow, startCollumn, endRow, endCollumn)
            end
        end

        local rowDiff = math.abs(endRow - startRow)
        local colDiff = math.abs(endCollumn - startCollumn)

        -- bishop moves
        if startPiece:lower() == "b" then
            -- only perfect diagonals
            if rowDiff == colDiff then
                return pathCheck(startRow, startCollumn, endRow, endCollumn)
            end
        end

        -- queen moves
        if startPiece:lower() == "q" then
            if (startRow == endRow) or (startCollumn == endCollumn) or (rowDiff == colDiff) then
                return pathCheck(startRow, startCollumn, endRow, endCollumn)
            end
        end

        -- knight moves
        if startPiece:lower() == "n" then
            -- 2 up/down + 1 right/left or vice versa
            if (rowDiff == 2 and colDiff == 1) or (rowDiff == 1 and colDiff == 2) then
                return true
            end
        end
    end
end

createBoardFromPosition(chessGamePosition)