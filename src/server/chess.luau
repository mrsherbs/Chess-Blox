-- hobby project for soph. programming/chess club
-- module script for containing chess
-- promotion
local chess = {}

local helpers = require(script.Parent.helpers)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- lowercase = white, uppercase = black
-- enpassant, checks, and checkmate checks, castling <-- (todo)
-- fen notation for stockfish
-- TODO: PROMOTION, FIX EN PASSANT, ENGINE
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
    ["movesSinceCapture"] = "0", -- these are half moves to be exact (aka: piles)
    ["moveNumber"] = 1,
    ["kingMovedWhite"] = false,
    ["kingMovedBlack"] = false,
    ["rookMovedWhiteA"] = false,
    ["rookMovedWhiteH"] = false,
    ["rookMovedBlackA"] = false, -- a coll rook
    ["rookMovedBlackH"] = false -- h coll rook
}

local getAllValidMovesForPiece, executeMoveOnBoard
-- forward declarations due to mutual recursion in these 3 functions
local createBoardFromPosition, makeMove, displayValidMovesForPiece

local function pieceIsWhite(piece)
    return piece == piece:lower()
end

-- all enemy pieces on board
local function getAllEnemyPieces(checkBoard, isCurrentPieceWhite)
    local pieces = {}

    for rowIndex, row in ipairs(checkBoard) do
        for collumnIndex, piece in ipairs(row) do
            -- if friendly team ~= piece team
            if piece ~= "" and isCurrentPieceWhite ~= pieceIsWhite(piece) then
                -- return piece position and type
                table.insert(pieces, {rowIndex, collumnIndex, piece})
            end
        end
    end

    return pieces
end

-- king pos, row, col
local function getKingPosition(checkBoard, isCurrentPieceWhite)
    local kingSymbol = isCurrentPieceWhite and "k" or "K"

    for rowIndex, row in ipairs(checkBoard) do
        local kingIndex = table.find(row, kingSymbol)
        if kingIndex then
            return rowIndex, kingIndex
        end
    end

    return false
end

-- move piece from start to end location
-- ignores all chess rules
local function movePieceFromPosition(position, startR, startC, endR, endC, enPassant)
    local piece = position[startR][startC]
    position[startR][startC] = ""
    position[endR][endC] = piece
	
    if enPassant then
        position[enPassant[1]][enPassant[2]] = ""
    end

    -- if piece is being captured, return true, else false
    local isCaptureMove = position[endR][endC] ~= "" and true or false

    return position, isCaptureMove
end

-- recursively checks all enemy pieces to see if they are able to capture the friendly king
local function isInCheck(checkBoard, checkInfo, isCurrentPieceWhite)
    checkBoard = helpers.deepCopy(checkBoard)
    checkInfo = helpers.deepCopy(checkInfo)

    -- ensure nobody can use a castling move to escape from checks
    if isCurrentPieceWhite then
        checkInfo["kingMovedWhite"] = true
    else
        checkInfo["kingMovedBlack"] = true
    end

    local kingRow, kingCol = getKingPosition(checkBoard, isCurrentPieceWhite)
    local enemies = getAllEnemyPieces(checkBoard, isCurrentPieceWhite)

    for _, pieceInfo in ipairs(enemies) do
        -- simulate enemy movement for each enemy piece
        local enemyRow, enemyCol = pieceInfo[1], pieceInfo[2]
        
        -- swap to enemy team for simulation
        if isCurrentPieceWhite then
            checkInfo["nextPlayer"] = "b"
        else
            checkInfo["nextPlayer"] = "w"
        end

        local canAttackKing = executeMoveOnBoard(checkBoard, checkInfo, enemyRow, enemyCol, kingRow, kingCol)

        -- if any enemy can attack the kings position (king is in check) ^^
        if canAttackKing thenS
            return true
        end
    end

    -- no enemy piece can attack the king, so its not in check
    return false
end

-- i need better func names lol
-- check for check and reset en passant
local function checkCheckEnPassantReset(boardCheck, infoCheck, startR, startC, endR, endC, isCurrentPieceWhite, enPassant)
    local simulatedBoard = helpers.deepCopy(boardCheck)

    -- piece row, piece col
    -- since enpassant[1] is also a row (but it's the square that is captured)
    if enPassant then
        enPassant = {infoCheck["enPassantCoordinates"][3], infoCheck["enPassantCoordinates"][2]}
	end

    local newBoard, isCaptureMove = movePieceFromPosition(simulatedBoard, startR, startC, endR, endC, enPassant)

    -- check if this move leads directly to check
    if isInCheck(newBoard, infoCheck, isCurrentPieceWhite) then
        return false
    end

    -- reset en passant coords
    infoCheck["enPassantCoordinates"] = "-"

    return newBoard, isCaptureMove, infoCheck
end

function executeMoveOnBoard(board, info, startRow, startCollumn, endRow, endCollumn)
    board = helpers.deepCopy(board)
    info = helpers.deepCopy(info)
    local startPiece = board[startRow][startCollumn]
    local endPiece = board[endRow][endCollumn]
    local isCurrentPieceWhite = pieceIsWhite(startPiece)
    local isEnemyPieceWhite = pieceIsWhite(endPiece)

    -- no fake pieces
    if startPiece == "" then
        return false
    end
    
    -- turn check
    if isCurrentPieceWhite then
        if info["nextPlayer"] == "b" then
            return false
        end
    else
        if info["nextPlayer"] == "w" then
            return false
        end
    end

    -- within 8x8 grid
    local function areCoordinatesInBounds(startR, startC, endR, endC)
        local maxRow, maxCol = #board, #board[1]
        return startR >= 1 and startR <= maxRow and startC >= 1 and startC <= maxCol and
               endR >= 1 and endR <= maxRow and endC >= 1 and endC <= maxCol
    end

    local function isEmptySquare(row, col)
        return board[row][col] == ""
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

    local function isEnPassantSquare(row, col)
        -- compare row and col from param to that of en passant coord table
        local enPassantRow, enPassantCol = info["enPassantCoordinates"][1], info["enPassantCoordinates"][2]
        warn(enPassantRow, enPassantCol, row, col)

        if enPassantRow and enPassantCol then
            if enPassantRow == row and enPassantCol == col then
                return true
            end
        end

        return false
    end

    -- this only checks pieces between start and end
    local function pathCheck(startR, startC, endR, endC)
        local rowIncrement = startR == endR and 0 or (endR > startR and 1 or -1)
        local colIncrement = startC == endC and 0 or (endC > startC and 1 or -1)
        local r, c = startR + rowIncrement, startC + colIncrement

        -- iter through pieces path, check for pieces blocking it
        while r ~= endR or c ~= endC do
            if board[r][c] ~= "" then
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
                    local newBoard, isCaptureMove, newInfo = checkCheckEnPassantReset(board, info, startRow, startCollumn, endRow, endCollumn, isCurrentPieceWhite)
                    return newBoard, isCaptureMove, newInfo
                end

                -- two square
                if (endRow == startRow + 2 * forwardDirection) and (startRow == startRowForDoubleMove) then
                    if isEmptySquare(startRow + forwardDirection, startCollumn) and isEmptySquare(endRow, endCollumn) then
                        local newBoard, isCaptureMove, newInfo = checkCheckEnPassantReset(board, info, startRow, startCollumn, endRow, endCollumn, isCurrentPieceWhite)

                        -- en passant coordinates + where the pawn to die is at
                        info["enPassantCoordinates"] = {startRow + 1 * forwardDirection, startCollumn, startRow + 2 * forwardDirection}
                        print(info.enPassantCoordinates)

                        return newBoard, isCaptureMove, newInfo
                    end
                end
                
                -- capture moves
            elseif (endCollumn == startCollumn + 1) or (endCollumn == startCollumn - 1) then
                local enPassantSquare = isEnPassantSquare(endRow, endCollumn)
                print(enPassantSquare)
                if (endRow == startRow + forwardDirection) and (isEnemySquare(endRow, endCollumn) or enPassantSquare) then
                    local newBoard, isCaptureMove, newInfo = checkCheckEnPassantReset(board, info, startRow, startCollumn, endRow, endCollumn, isCurrentPieceWhite, enPassantSquare)
                    return newBoard, isCaptureMove, newInfo
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

                local newBoard, isCaptureMove, newInfo = checkCheckEnPassantReset(board, info, startRow, startCollumn, endRow, endCollumn, isCurrentPieceWhite)
                return newBoard, isCaptureMove, newInfo
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

                    local newBoard, isCaptureMove, newInfo = checkCheckEnPassantReset(board, info, startRow, startCollumn, endRow, endCollumn, isCurrentPieceWhite)
                    return newBoard, isCaptureMove, newInfo
                end
            end
        end

        -- bishop moves
        if startPiece:lower() == "b" then
            -- only perfect diagonals
            if rowDiff == colDiff then
                if pathCheck(startRow, startCollumn, endRow, endCollumn) then
                    local newBoard, isCaptureMove, newInfo = checkCheckEnPassantReset(board, info, startRow, startCollumn, endRow, endCollumn, isCurrentPieceWhite)
                    return newBoard, isCaptureMove, newInfo
                end
            end
        end

        -- queen moves
        if startPiece:lower() == "q" then
            -- if moving in same row, or in same collumn, or diagonally
            if (startRow == endRow) or (startCollumn == endCollumn) or (rowDiff == colDiff) then
                if pathCheck(startRow, startCollumn, endRow, endCollumn) then
                    local newBoard, isCaptureMove, newInfo = checkCheckEnPassantReset(board, info, startRow, startCollumn, endRow, endCollumn, isCurrentPieceWhite)
                    return newBoard, isCaptureMove, newInfo
                end
            end
        end

        -- knight moves
        if startPiece:lower() == "n" then
            -- 2 up/down + 1 right/left or vice versa
            if (rowDiff == 2 and colDiff == 1) or (rowDiff == 1 and colDiff == 2) then
                local newBoard, isCaptureMove, newInfo = checkCheckEnPassantReset(board, info, startRow, startCollumn, endRow, endCollumn, isCurrentPieceWhite)
                return newBoard, isCaptureMove, newInfo
            end
        end

    -- castling
    elseif startPiece:lower() == "k" and endPiece:lower() == "r" then
        -- king either direction 2 square towards rook
        -- rook moves 1 kingside, rook 3 queenside A file
        local kingMoved        
        local rookMoved

        if isCurrentPieceWhite then
            kingMoved = info["kingMovedWhite"]
        else
            kingMoved = info["kingMovedBlack"]
        end

        -- i wouldnt repeat myself here and then in the next block but to be honest
        -- i dont think theres a good way to do this w/out ruining readability
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

            if endCollumn == 1 then
                if isCurrentPieceWhite then
                    info["rookMovedWhiteA"] = true
                else
                    info["rookMovedBlackA"] = true
                end
            elseif endCollumn == 8 then
                if isCurrentPieceWhite then
                    info["rookMovedWhiteH"] = true
                else
                    info["rookMovedBlackH"] = true
                end
            end

            -- move the king, king only changes his collumn !
            local newBoard, isCaptureMove = checkCheckEnPassantReset(board, info, startRow, startCollumn, startRow, kingNewCollumn, isCurrentPieceWhite)
            -- change this behaviour if needed, the end collumn is where the rook is
            -- rook starts off where player selected to move, which is why we use endcollumn as 2nd arg
            if newBoard then
                newBoard, isCaptureMove = checkCheckEnPassantReset(newBoard, info, startRow, endCollumn, startRow, rookNewCollumn, isCurrentPieceWhite)
                return newBoard, isCaptureMove, info
            else
                return false
            end
        end
    end
end

-- all valid moves for given piece at row collumn in {1-8, 1-8} format
function getAllValidMovesForPiece(board, info, row, collumn)
    local moves = {}

    for rowIndex = 1, 8 do
        for collumnIndex = 1, 8 do
            if executeMoveOnBoard(board, info, row, collumn, rowIndex, collumnIndex) then
                table.insert(moves, {rowIndex, collumnIndex})
            end
        end
    end

    return moves
end

-- just setup the physical board
createBoardFromPosition = function(position)
    local board = workspace.Board

    helpers.destroyDescendants(board.Pieces)
    helpers.destroyDescendants(board.Circles)

    for rowIndex, row in ipairs(position) do
        for collumnIndex, piece in ipairs(row) do
            if piece ~= "" then
                local pieceMesh = ReplicatedStorage.Pieces[piece:lower()]:Clone()
                pieceMesh.CFrame = board[rowIndex][collumnIndex].CFrame * CFrame.new(Vector3.new(0, pieceMesh.Size.Y / 2, 0))
                
                -- set piece color
                if pieceIsWhite(piece) then
                    pieceMesh.BrickColor = BrickColor.new("Institutional white")
                    pieceMesh.CFrame = pieceMesh.CFrame * CFrame.Angles(0, math.rad(180), 0)
                    pieceMesh.Name = piece:upper()
                else
                    pieceMesh.BrickColor = BrickColor.new("Really black")
                end

                -- reset and display
                pieceMesh.ClickDetector.MouseClick:Connect(function()
                    helpers.destroyDescendants(board.Circles)
                    displayValidMovesForPiece(rowIndex, collumnIndex)
                end)

                pieceMesh.Parent = board.Pieces
            end
        end
    end
end

-- checkmate check
-- ran after every move
local function isCheckmate(board, info)
    local currentPlayer = info["nextPlayer"]
    local isCurrentPieceWhite

    if currentPlayer == "w" then
        isCurrentPieceWhite = true
    else
        isCurrentPieceWhite = false
    end

    if not isInCheck(board, info, isCurrentPieceWhite) then
        return false
    end

    -- for every square
    for row = 1, 8 do
        for col = 1, 8 do
            -- get the piece on the square
            local piece = board[row][col]

            if piece ~= "" and (pieceIsWhite(piece) == isCurrentPieceWhite) then
                local validMoves = getAllValidMovesForPiece(board, info, row, col)

                -- check each valid move for the current piece
                for _, move in ipairs(validMoves) do
                    local endRow, endCol = move[1], move[2]

                    -- sim the board and game info after making the move
                    local simulatedBoard = helpers.deepCopy(board)
                    local simulatedInfo = helpers.deepCopy(info)

                    -- move the piece on the simulated board
                    local newBoard, _, _ = checkCheckEnPassantReset(simulatedBoard, simulatedInfo, row, col, endRow, endCol)

                    if not isInCheck(newBoard, simulatedInfo, isCurrentPieceWhite) then
                        return false
                    end
                end
            end
        end
    end

    return true
end

-- is stalemate
-- ran after every move
local function isStalemate(board, info)
    local currentPlayer = info["nextPlayer"]
    local isCurrentPieceWhite

    if currentPlayer == "w" then
        isCurrentPieceWhite = true
    else
        isCurrentPieceWhite = false
    end

    for row = 1, 8 do
        for col = 1, 8 do
            local piece = board[row][col]
            
            -- check if the piece belongs to the current player
            if piece ~= "" and (pieceIsWhite(piece) == isCurrentPieceWhite) then
                local validMoves = getAllValidMovesForPiece(board, info, row, col)
                
                if #validMoves > 0 then
                    return false
                end
            end
        end
    end

    return not isInCheck(board, info)
end

makeMove = function(startR, startC, endR, endC)
    -- new board setup from valid func
    -- checkmate check
    local board, captured, info = executeMoveOnBoard(chess.chessGamePosition, chess.chessGameInfo, startR, startC, endR, endC)

    if board then
        -- TODO: add promotion
        chess.chessGamePosition = board
        chess.chessGameInfo = info
    
        chess.chessGameInfo.moveNumber = chess.chessGameInfo.moveNumber + 1
    
        if captured then
            chess.chessGameInfo["movesSinceCapture"] = 0
        else
            chess.chessGameInfo["movesSinceCapture"] = chess.chessGameInfo["movesSinceCapture"] + 1
        end
    
        createBoardFromPosition(chess.chessGamePosition)

        -- swap player
        if chess.chessGameInfo.nextPlayer == "w" then
            chess.chessGameInfo.nextPlayer = "b"
        else
            chess.chessGameInfo.nextPlayer = "w"
        end

        -- final checks for checkmate and stalemate
        if isCheckmate(chess.chessGamePosition, chess.chessGameInfo) then
            print("Checkmate")
        end

        if isStalemate(chess.chessGamePosition, chess.chessGameInfo) then
            print("Stalemate")
        end
    end
end

displayValidMovesForPiece = function(row, collumn)
    local validMoves = getAllValidMovesForPiece(chess.chessGamePosition, chess.chessGameInfo, row, collumn)

    -- setup move circles for all valid moves found
    for _, move in ipairs(validMoves) do
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