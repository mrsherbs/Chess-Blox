-- hobby project for soph. programming/chess club
-- module script for containing chess
local chess = {}

local helpers = require(script.Parent.helpers)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- lowercase = white, uppercase = black
-- enpassant, checks, and checkmate checks, castling <-- (todo)
-- fen notation for stockfish
chess.chessGamePosition = {
    {"R", "N", "B", "Q", "K", "B", "N", "R"}, -- row 1 (black)
    {"P", "P", "P", "P", "P", "P", "P", "P"}, -- row 2 (black pawns)
    {"", "", "", "", "", "", "", ""},         -- row 3 (empty)
    {"", "", "", "", "", "", "", ""},         -- row 4 (empty)
    {"", "", "", "", "", "", "", ""},         -- row 5 (empty)
    {"", "", "", "", "", "", "", ""},         -- row 6 (empty)
    {"p", "p", "p", "p", "p", "p", "p", "p"}, -- row 7 (white pawns)
    {"r", "n", "b", "q", "k", "b", "n", "r"}  -- row 8 (white)
}

-- fen notation: w or b next player
chess.chessGameInfo = {
    ["nextPlayer"] = "w",
    ["enPassantCoordinates"] = "-", -- implement, only one en passant possible at a time (?)
    ["movesSinceCapture"] = "0",
    ["moveNumber"] = 1,
    ["kingMovedWhite"] = false,
    ["kingMovedBlack"] = false,
    ["rookMovedWhiteA"] = false,
    ["rookMovedWhiteH"] = false,
    ["rookMovedBlackA"] = false, -- a row rook
    ["rookMovedBlackH"] = false -- h row rook
}

local function pieceIsWhite(piece)
    return piece == piece:lower()
end

local function movePieceFromPosition(position, startR, startC, endR, endC)
    local piece = position[startR][startC]
    position[startR][startC] = ""
    position[endR][endC] = piece

    -- if piece is being captured, return true, else false
    local isCaptureMove = position[endR][endC] ~= "" and true or false

    return position, isCaptureMove
end

local function isMoveValid(startRow, startCollumn, endRow, endCollumn)
    local board = helpers.deepCopy(chess.chessGamePosition)
    local info = helpers.deepCopy(chess.chessGameInfo)
    local startPiece = board[startRow][startCollumn]
    local endPiece = board[endRow][endCollumn]
    local isCurrentPieceWhite = pieceIsWhite(startPiece)
    local isEnemyPieceWhite = pieceIsWhite(endPiece)

    -- no fake pieces
    if startPiece == "" then
        return false
    end

    -- recursively checks all enemy pieces to see if they are able to capture the friendly king
    local function isInCheck()
        
    end

    -- within 8x8 grid
    local function areCoordinatesInBounds(startR, startC, endR, endC)
        local maxRow, maxCol = #board, #board[1]
        return startR >= 1 and startR <= maxRow and startC >= 1 and startC <= maxCol and
               endR >= 1 and endR <= maxRow and endC >= 1 and endC <= maxCol
    end

    local function isEmptySquare(row, col)
        return chess.chessGamePosition[row][col] == ""
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

    -- this only checks pieces between start and end
    local function pathCheck(startR, startC, endR, endC)
        local rowIncrement = startR == endR and 0 or (endR > startR and 1 or -1)
        local colIncrement = startC == endC and 0 or (endC > startC and 1 or -1)
        local r, c = startR + rowIncrement, startC + colIncrement

        -- iter through pieces path, check for pieces blocking it
        while r ~= endR or c ~= endC do
            if chess.chessGamePosition[r][c] ~= "" then
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

    -- is capturable (ie. no friendly pieces), have moved 1 square
    if isCapturableSquare(endRow, endCollumn) and not (startRow == endRow and startCollumn == endCollumn) then
        if startPiece:lower() == "p" then
            local forwardDirection = isCurrentPieceWhite and -1 or 1
            local startRowForDoubleMove = isCurrentPieceWhite and 7 or 2
            
            if endCollumn == startCollumn then
                -- one square move
                if (endRow == startRow + forwardDirection) and isEmptySquare(endRow, endCollumn) then
                    return movePieceFromPosition(board, startRow, startCollumn, endRow, endCollumn), info
                end

                -- two square
                if (endRow == startRow + 2 * forwardDirection) and (startRow == startRowForDoubleMove) then
                    if isEmptySquare(startRow + forwardDirection, startCollumn) and isEmptySquare(endRow, endCollumn) then
                        return movePieceFromPosition(board, startRow, startCollumn, endRow, endCollumn), info
                    end
                end
                
                -- capture moves
            elseif (endCollumn == startCollumn + 1) or (endCollumn == startCollumn - 1) then
                if (endRow == startRow + forwardDirection) and isEnemySquare(endRow, endCollumn) then
                    return movePieceFromPosition(board, startRow, startCollumn, endRow, endCollumn), info
                end
            end
        end

        local rowDiff = math.abs(endRow - startRow)
        local colDiff = math.abs(endCollumn - startCollumn)

        -- king moves
        if startPiece:lower() == "k" then
            if (rowDiff <= 1 and colDiff <= 1) then
                if isCurrentPieceWhite then
                    info["kingMovedWhite"] = true
                else
                    info["kingMovedBlack"] = true
                end

                return movePieceFromPosition(board, startRow, startCollumn, endRow, endCollumn), info
            end
        end

        -- rook moves
        if startPiece:lower() == "r" then
            if (startRow == endRow) or (startCollumn == endCollumn) then
                if pathCheck(startRow, startCollumn, endRow, endCollumn) then

                    if isCurrentPieceWhite then
                        if endCollumn == 1 then
                            info["rookMovedWhiteA"] = true
                        else
                            info["rookMovedWhiteH"] = true
                        end
                    else
                        if endCollumn == 1 then
                            info["rookMovedBlackA"] = true
                        else
                            info["rookMovedBlackH"] = true
                        end
                    end

                    return movePieceFromPosition(board, startRow, startCollumn, endRow, endCollumn), info
                end
            end
        end

        -- bishop moves
        if startPiece:lower() == "b" then
            -- only perfect diagonals
            if rowDiff == colDiff then
                if pathCheck(startRow, startCollumn, endRow, endCollumn) then
                    return movePieceFromPosition(board, startRow, startCollumn, endRow, endCollumn), info
                end
            end
        end

        -- queen moves
        if startPiece:lower() == "q" then
            -- if moving in same row, or in same collumn, or diagonally
            if (startRow == endRow) or (startCollumn == endCollumn) or (rowDiff == colDiff) then
                if pathCheck(startRow, startCollumn, endRow, endCollumn) then
                    return movePieceFromPosition(board, startRow, startCollumn, endRow, endCollumn), info
                end
            end
        end

        -- knight moves
        if startPiece:lower() == "n" then
            -- 2 up/down + 1 right/left or vice versa
            if (rowDiff == 2 and colDiff == 1) or (rowDiff == 1 and colDiff == 2) then
                return movePieceFromPosition(board, startRow, startCollumn, endRow, endCollumn), info
            end
        end

    -- castling
    elseif startPiece:lower() == "k" and endPiece:lower() == "r" then
        -- king either direction 2 square towards rook
        -- rook moves 1 kingside, rook 3 queenside A file
        local kingMoved = isCurrentPieceWhite and info["kingMovedWhite"] or info["kingMovedBlack"]
        local rookMoved

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

            rookMoved = true
            kingMoved = true

            -- move the king
            movePieceFromPosition(board, startRow, startCollumn, startRow, kingNewCollumn)
            -- change this behaviour if needed, the end collumn is where the rook is
            return movePieceFromPosition(board, startRow, endCollumn, startRow, rookNewCollumn), info
        end
    end
end

local function getAllValidMovesForPiece(row, collumn)
    local moves = {}

    for rowIndex = 1, 8 do
        for collumnIndex = 1, 8 do
            if isMoveValid(row, collumn, rowIndex, collumnIndex) then
                table.insert(moves, {rowIndex, collumnIndex})
            end
        end
    end

    return moves
end

-- forward declarations
local createBoardFromPosition, makeMove, displayValidMovesForPiece

createBoardFromPosition = function(position)
    local board = workspace.Board

    helpers.destroyDescendants(board.Pieces)
    helpers.destroyDescendants(board.Circles)

    for rowIndex, row in ipairs(position) do
        for collumnIndex, piece in ipairs(row) do
            if piece ~= "" then
                local pieceMesh = ReplicatedStorage.Pieces[piece:lower()]:Clone()
                pieceMesh.CFrame = board[rowIndex][collumnIndex].CFrame * CFrame.new(Vector3.new(0, pieceMesh.Size.Y / 2, 0))

                if pieceIsWhite(piece) then
                    pieceMesh.BrickColor = BrickColor.new("Institutional white")
                    pieceMesh.CFrame = pieceMesh.CFrame * CFrame.Angles(0, math.rad(180), 0)
                    pieceMesh.Name = piece:upper()
                else
                    pieceMesh.BrickColor = BrickColor.new("Really black")
                end

                pieceMesh.ClickDetector.MouseClick:Connect(function()
                    helpers.destroyDescendants(board.Circles)
                    displayValidMovesForPiece(rowIndex, collumnIndex)
                end)

                pieceMesh.Parent = board.Pieces
            end
        end
    end
end

makeMove = function(startR, startC, endR, endC)
    -- new board setup from valid func
    -- checkmate check
    local board, captured, info = isMoveValid(startR, startC, endR, endC)

    chess.chessGamePosition = board
    chess.chessGameInfo = info

    -- swap player
    if chess.chessGameInfo.nextPlayer == "w" then
        chess.chessGameInfo.nextPlayer = "b"
    else
        chess.chessGameInfo.nextPlayer = "w"
    end

    chess.chessGameInfo.moveNumber = chess.chessGameInfo.moveNumber + 1

    if captured then
        chess.chessGameInfo["movesSinceCapture"] = 0
    else
        chess.chessGameInfo["movesSinceCapture"] = chess.chessGameInfo["movesSinceCapture"] + 1
    end

    createBoardFromPosition(chess.chessGamePosition)
end

displayValidMovesForPiece = function(row, collumn)
    local validMoves = getAllValidMovesForPiece(row, collumn)

    for _, move in pairs(validMoves) do
        local board = workspace.Board
        local circleClone = ReplicatedStorage.Pieces.Circle:Clone()
        local rowMove = move[1]
        local collumnMove = move[2]

        circleClone.CFrame = board[rowMove][collumnMove].CFrame * CFrame.new(0, circleClone.Size.Y / 2, 0)
        circleClone.Parent = board.Circles

        circleClone.ClickDetector.MouseClick:Connect(function()
            makeMove(row, collumn, rowMove, collumnMove)
        end)
    end
end

chess.init = function()
    createBoardFromPosition(chess.chessGamePosition)
end

return chess