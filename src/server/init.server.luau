-- hobby project for soph. programming/chess club

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- uppercase = white, lowercase = black
-- enpassant, checks, and checkmate checks, castling(todo)
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
    ["rookMovedBlackA"] = false, -- a row rook
    ["rookMovedBlackH"] = false -- h rook
}

-- roblox lua table.copy does not behave like i expected with nested tables
-- any changes to a nested table will replicate
local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			v = deepCopy(v)
		end
		copy[k] = v
	end
	return copy
end

local function pieceIsWhite(piece)
    return piece == piece:lower()
end

local function movePiece(position, startR, startC, endR, endC)
    -- should i be returning it if it already changes the table inputted? it helps with return statements
    local piece = position[startR][startC]
    position[startR][startC] = ""
    position[endR][endC] = piece

    return position
end

-- square is 4x4 studs, 64 squares, alternating white and black
local function createBoardFromPosition(position)
    local board = workspace.Board
    local boardPieces = board.Pieces

    for _, oldPiece in board.Pieces:GetDescendants() do
        oldPiece:Destroy()
    end

    for rowIndex, row in ipairs(chessGamePosition) do
        for collumnIndex, piece in ipairs(row) do
            if piece ~= "" then
                -- get piece from lowercase ident.
                local pieceMesh = ReplicatedStorage.Pieces[piece:lower()]:Clone()
                -- height and pos alignment
                pieceMesh.CFrame = board[rowIndex][collumnIndex].CFrame * CFrame.new(Vector3.new(0, pieceMesh.Size.Y / 2, 0))

                if pieceIsWhite(piece) then
                    pieceMesh.BrickColor = BrickColor.new("Institutional white")
                    -- rotate part to face proper direction relative to board
                    pieceMesh.CFrame = pieceMesh.CFrame * CFrame.Angles(0, math.rad(180), 0)
                    pieceMesh.Name = piece:upper()
                else
                    pieceMesh.BrickColor = BrickColor.new("Really black")
                end

                pieceMesh.Parent = board.Pieces
            end
        end
    end
end

local function isMoveValid(startRow, startCollumn, endRow, endCollumn)
    local board = deepCopy(chessGamePosition)
    local info = deepCopy(chessGameinfo)
    local startPiece = board[startRow][startCollumn]
    local endPiece = board[endRow][endCollumn]
    -- i think is prefix is better used for functions but oh well
    local isCurrentPieceWhite = pieceIsWhite(startPiece)
    local isEnemyPieceWhite = pieceIsWhite(endPiece)

    -- no fake pieces
    if startPiece == "" then
        return false
    end

    -- implement
    local function isInCheck()
        
    end

    -- within 8x8 grid
    local function areCoordinatesInBounds(startR, startC, endR, endC)
        local maxRow, maxCol = #board, #board[1]
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

    if not areCoordinatesInBounds(startRow, startCollumn, endRow, endCollumn) then
        return false
    end

    -- is in bounds, is capturable (ie. no friendly pieces), have moved 1 square
    if isCapturableSquare(endRow, endCollumn) and not (startRow == endRow and startCollumn == endCollumn) then
        if startPiece:lower() == "p" then
            local forwardDirection = isCurrentPieceWhite and -1 or 1
            local startRowForDoubleMove = isCurrentPieceWhite and 7 or 2
            
            if endCollumn == startCollumn then
                -- one square move
                if (endRow == startRow + forwardDirection) and isEmptySquare(endRow, endCollumn) then
                    return movePiece(board, startRow, startCollumn, endRow, endCollumn)
                end

                -- two square
                if (endRow == startRow + 2 * forwardDirection) and (startRow == startRowForDoubleMove) then
                    if isEmptySquare(startRow + forwardDirection, startCollumn) and isEmptySquare(endRow, endCollumn) then
                        return movePiece(board, startRow, startCollumn, endRow, endCollumn)
                    end
                end
                
                -- capture moves
            elseif (endCollumn == startCollumn + 1) or (endCollumn == startCollumn - 1) then
                if (endRow == startRow + forwardDirection) and isEnemySquare(endRow, endCollumn) then
                    return movePiece(board, startRow, startCollumn, endRow, endCollumn)
                end
            end
        end

        local rowDiff = math.abs(endRow - startRow)
        local colDiff = math.abs(endCollumn - startCollumn)

        -- king moves
        if startPiece:lower() == "k" then
            if (rowDiff <= 1 and colDiff <= 1) then
                return movePiece(board, startRow, startCollumn, endRow, endCollumn)
            end
        end

        -- rook moves
        if startPiece:lower() == "r" then
            if (startRow == endRow) or (startCollumn == endCollumn) then
                if pathCheck(startRow, startCollumn, endRow, endCollumn) then
                    return movePiece(board, startRow, startCollumn, endRow, endCollumn)
                end
            end
        end

        -- bishop moves
        if startPiece:lower() == "b" then
            -- only perfect diagonals
            if rowDiff == colDiff then
                if pathCheck(startRow, startCollumn, endRow, endCollumn) then
                    return movePiece(board, startRow, startCollumn, endRow, endCollumn)
                end
            end
        end

        -- queen moves
        if startPiece:lower() == "q" then
            -- if moving in same row, or in same collumn, or diagonally
            if (startRow == endRow) or (startCollumn == endCollumn) or (rowDiff == colDiff) then
                if pathCheck(startRow, startCollumn, endRow, endCollumn) then
                    return movePiece(board, startRow, startCollumn, endRow, endCollumn)
                end
            end
        end

        -- knight moves
        if startPiece:lower() == "n" then
            -- 2 up/down + 1 right/left or vice versa
            if (rowDiff == 2 and colDiff == 1) or (rowDiff == 1 and colDiff == 2) then
                return movePiece(board, startRow, startCollumn, endRow, endCollumn)
            end
        end
    -- castling
    -- TODO: end piece in chess.com is not rook! but instead the square next to the rook
    -- decide whether to keep this behaviour or not
    elseif startPiece:lower() == "k" and endPiece == "r" then
        -- king either direction 2 square towards rook
        -- rook moves 1 kingside, rook 3 queenside A file
        local kingMoved = isCurrentPieceWhite and info["kingMovedWhite"] or info["kingMovedBlack"]
        local rookMoved

        -- im not making this a ternary lol
        if endCollumn == 1 then
            if isCurrentPieceWhite then
                rookMoved = info["rookMovedWhiteA"]
            else
                rookMoved = info["rookMovedBlackA"]
            end
        elseif endCollumn == 8 then
            if isCurrentPieceWhite then
                rookMoved = info["rookMovedWhiteH"]
            else
                rookMoved = info["rookMovedBlackH"]
            end
        end

        if not kingMoved and not rookMoved and pathCheck(startRow, startCollumn, endRow, endCollumn) then
            -- 3 for queenside, 7 for kingside
            local kingNewCollumn = endCollumn == 1 and 3 or 7
            -- 4 for queenside, 6 for kingside
            local rookNewCollumn = endCollumn == 1 and 4 or 6

            -- move the king
            movePiece(board, startRow, startCollumn, startRow, kingNewCollumn)
            -- change this behaviour if needed, the end collumn is where the rook is
            return movePiece(board, startRow, endCollumn, startRow, rookNewCollumn)
        end
    end
end

local function getAllValidMovesForPiece(row, collumn)
    local moves = {}

    for rowIndex = 1, 8 do
        for collumnIndex = 1, 8 do
            if rowIndex == 4 then
                if collumnIndex == 1 then
                    print(row, collumn, rowIndex, collumnIndex)
                end
            end

            if isMoveValid(row, collumn, rowIndex, collumnIndex) then
                table.insert(moves, {rowIndex, collumnIndex})
            end
        end
    end

    return moves
end

local function displayValidMovesForPiece(row, collumn)
    local validMoves = getAllValidMovesForPiece(row, collumn)
    print(validMoves)
end

-- local function makeMove(startR, startC, endR, endC)
--     if isMoveValid(startR, startC, endR, endC) then
--         local piece = chessGamePosition[startR][startC]

--         createBoardFromPosition(chessGamePosition)
--     end
-- end

createBoardFromPosition(chessGamePosition)
displayValidMovesForPiece(1, 1)