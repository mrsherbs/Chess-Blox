-- hobby project for soph. programming/chess club
-- module script for containing chess functions

-- im not too proud about the way i wrote en passant but im probably not gonna fix it because
-- i dont even really like chess that much
-- ill fix it if they make chess 2
local chess = {}

local helpers = require(script.Parent.helpers)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- lowercase = white, uppercase = black
-- enpassant, checks, and checkmate checks, castling <-- (todo)
-- fen notation for stockfish
-- TODO: PROMOTION, ENGINE
chess.chessGamePosition = {
    {"R", "N", "B", "Q", "K", "B", "N", "R"}, -- row 1 (black)
    {"P", "P", "P", "P", "P", "P", "P", "P"}, -- row 2 (black pawns)
    {"", "", "", "Q", "Q", "Q", "", ""},         -- row 3 (empty)
    {"", "", "", "", "", "", "", ""},         -- row 4 (empty)
    {"", "", "", "", "", "", "", ""},         -- row 5 (empty)
    {"", "", "", "", "", "", "", ""},         -- row 6 (empty)
    {"p", "p", "p", "p", "p", "p", "p", "p"}, -- row 7 (white pawns)
    {"r", "n", "b", "q", "k", "b", "n", "r"}  -- row 8 (white)
}

-- fen notation: w or b next player
chess.chessGameInfo = {
    ["nextPlayer"] = "w", -- white goes first
    ["enPassantCoordinates"] = "-", -- either - or dict
    ["movesSinceCapture"] = "0", -- these are half moves to be exact (aka: piles)
    ["moveNumber"] = 1,
    ["kingMovedWhite"] = true, -- all of these for castling checks
    ["kingMovedBlack"] = true,
    ["rookMovedWhiteA"] = false,
    ["rookMovedWhiteH"] = false,
    ["rookMovedBlackA"] = false, -- a coll rook
    ["rookMovedBlackH"] = false -- h coll rook
}

local function pieceIsWhite(piece)
    -- all white pieces are lowercase
    -- if the param is lowercase then it is white
    return piece == piece:lower()
end

-- representing 1, 8 times for an empty row is equal to just 8 in FEN
-- ex: Rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1
local function positionAndInfoToFEN(position, info)
    local str = ""

    -- piece position
    for rowIndex = 1, #position, 1 do
        local row = position[rowIndex]
        for columnIndex, piece in ipairs(row) do
            if piece == "" then
                -- add empty square
                str = str .. "1"
            else
                if pieceIsWhite(piece) then
                    piece = piece:upper()
                else
                    piece = piece:lower()
                end

                str = str .. piece
            end
        end

        if rowIndex < #position then
            str = str .. "/"  -- row separator
        end
    end

    -- next player
    str = str .. " " .. info["nextPlayer"]

    -- castling
    local castlingAvailability = ""

    castlingAvailability = castlingAvailability ..
	    (info["rookMovedWhiteA"] == false and "Q" or "") ..
	    (info["rookMovedWhiteH"] == false and "K" or "") ..
	    (info["rookMovedBlackA"] == false and "q" or "") ..
	    (info["rookMovedBlackH"] == false and "k" or "")

    str = str .. " " .. castlingAvailability

    -- en passant coordinates
    -- convert coll number to ascii equiv, row remains the same
    str = str .. " " .. (info["enPassantCoordinates"]["captureLocation"] and string.char(info["enPassantCoordinates"]["captureLocation"] + 96) .. info["enPassantCoordinates"]["collumn"] or "-")

    str = str .. " " .. math.round(info["moveNumber"] / 2) .. " " .. math.floor(info["moveNumber"] / 2)

    return str
end

local getAllValidMovesForPiece, executeMoveOnBoard
-- forward declarations due to mutual recursion in these 3 functions
local createBoardFromPosition, makeMove, displayValidMovesForPiece

-- all enemy pieces on board
local function getAllEnemyPieces(checkBoard, isCurrentPieceWhite)
    local pieces = {}

    -- iterate through given board to check all pieces
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

-- king pos returns row, col as a tuple
-- why? atm: checking for check/mate
local function getKingPosition(checkBoard, isCurrentPieceWhite)
    local kingSymbol = isCurrentPieceWhite and "k" or "K"

    for rowIndex, row in ipairs(checkBoard) do
        local kingIndex = table.find(row, kingSymbol)
        -- rowIndex[kingIndex] is king position
        if kingIndex then
            return rowIndex, kingIndex
        end
    end

    return false
end

-- moves piece at start position to end position, leaving behind an empty square
local function movePieceFromPosition(position, startR, startC, endR, endC, enPassant)
    local piece = position[startR][startC]
    position[startR][startC] = ""
    position[endR][endC] = piece
    
    -- en passant coords inputted are the position of the piece to be captured
    -- en passant coords as seen in given position are a table of 3 values when en passant is available:
    -- row of piece - pawn move direction (for displaying capture sqaure), the collumn (shared by both), actual row of piece
    -- this should be a dict and really only either index 1 or 3 is needed but
    -- i didn't think ahead
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
    -- this only applies to the simulated move
    checkInfo[isCurrentPieceWhite and "kingMovedWhite" or "kingMovedBlack"] = true

    local kingRow, kingCol = getKingPosition(checkBoard, isCurrentPieceWhite)
    local enemies = getAllEnemyPieces(checkBoard, isCurrentPieceWhite)

    -- ?
    if not kingRow or not kingCol then
        return true
    end

    for _, pieceInfo in ipairs(enemies) do
        -- simulate enemy movement for each enemy piece on a virtual board
        local enemyRow, enemyCol = pieceInfo[1], pieceInfo[2]
        
        -- swap to enemy team for simulation
        if isCurrentPieceWhite then
            checkInfo["nextPlayer"] = "b"
        else
            checkInfo["nextPlayer"] = "w"
        end

        -- remember that executeMove does not modify the given board, but instead returns a new board which
        -- you can use to replace the existing board
        -- since we are just simulating a move to see if it's possible
        -- it isn't saved
        local canAttackKing = executeMoveOnBoard(checkBoard, checkInfo, enemyRow, enemyCol, kingRow, kingCol)

        -- if any enemy can attack the kings position (king is in check) ^^
        -- below value is either false or a board table
        if canAttackKing then
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

    if enPassant then
        -- index 1 and 3 are rows, 2 is a collumn
        enPassant = {infoCheck["enPassantCoordinates"]["pieceLocation"], infoCheck["enPassantCoordinates"]["collumn"]}
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

-- takes a board, info, and positions as input
-- returns a board where piece at start pos moves to end pos
-- otherwise if it is impossible, return false
function executeMoveOnBoard(board, info, startRow, startCollumn, endRow, endCollumn)
    board = helpers.deepCopy(board)
    info = helpers.deepCopy(info)
    local startPiece = board[startRow][startCollumn]
    local endPiece = board[endRow][endCollumn]
    local isCurrentPieceWhite = pieceIsWhite(startPiece)
    local isEnemyPieceWhite = pieceIsWhite(endPiece)

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

    -- is the square able to be landed on by your piece
    local function isCapturableSquare(row, col)
        return isEmptySquare(row, col) or isEnemySquare(row, col)
    end

    -- is this square available for taking en passant
    local function isEnPassantSquare(row, col)
        -- compare row and col from param to that of en passant coord table
        local enPassantRow, enPassantCol = info["enPassantCoordinates"][1], info["enPassantCoordinates"][2]

        if enPassantRow == row and enPassantCol == col then
            return true
        end

        return false
    end

    -- this only checks pieces between start and end
    -- why? start piece is already known to be your piece
    -- end position is known to be capturable before this is ran
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

    -- no fake pieces
    if startPiece == "" then
        return false
    end
    
    -- turn check
    -- condition, true value, false value
    if info["nextPlayer"] ~= (isCurrentPieceWhite and "w" or "b") then
        return false
    end

    -- is capturable (ie. no friendly pieces) and check if piece has moved at least one square
    if isCapturableSquare(endRow, endCollumn) and not (startRow == endRow and startCollumn == endCollumn) then
        -- pawn moves
        if startPiece:lower() == "p" then
            -- pawns move either up one row or down one row
            -- pawns must be on the 7th row (if white) or 2nd row (if black) for double moves
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
                        info["enPassantCoordinates"] = {
                            ["captureLocation"] = startRow + 1 * forwardDirection, -- where enemy pawn will move when capturing en passant
                            ["collumn"] = startCollumn, -- pawn collumn
                            ["pieceLocation"] = startRow + 2 * forwardDirection -- location of the piece
                        }

                        return newBoard, isCaptureMove, newInfo
                    end
                end
                
                -- capture moves
            elseif (endCollumn == startCollumn + 1) or (endCollumn == startCollumn - 1) then
                local enPassantSquare = isEnPassantSquare(endRow, endCollumn)

                if (endRow == startRow + forwardDirection) and (isEnemySquare(endRow, endCollumn) or enPassantSquare) then
                    local newBoard, isCaptureMove, newInfo = checkCheckEnPassantReset(board, info, startRow, startCollumn, endRow, endCollumn, isCurrentPieceWhite, enPassantSquare)
                    return newBoard, isCaptureMove, newInfo
                end
            end
        end

        -- move
        local rowDiff = math.abs(endRow - startRow)
        local colDiff = math.abs(endCollumn - startCollumn)

        -- king moves
        -- TODO: fix this.. end piece sometimes ends up being an enemy lol
        if startPiece:lower() == "k"  then
            if (rowDiff <= 1 and colDiff <= 1) then
                -- for castling
                info[isCurrentPieceWhite and "kingMovedWhite" or "kingMovedBlack"] = true

                local newBoard, isCaptureMove, newInfo = checkCheckEnPassantReset(board, info, startRow, startCollumn, endRow, endCollumn, isCurrentPieceWhite)
                return newBoard, isCaptureMove, newInfo
            end

            -- king either direction 2 square towards rook
            -- rook moves 1 kingside, rook 3 queenside A file
            local rookMovedDictIndex

            -- just save the index in the info dict instead of the value of the info dict
            local kingMovedDictIndex = isCurrentPieceWhite and "kingMovedWhite" or "kingMovedBlack"

            if endCollumn == 1 or endCollumn == 2 or endCollumn == 3 then
                rookMovedDictIndex = isCurrentPieceWhite and "rookMovedWhiteA" or "rookMovedBlackA"
            elseif endCollumn == 8 or endCollumn == 7 or endCollumn == 6 then
                rookMovedDictIndex = isCurrentPieceWhite and "rookMovedWhiteH" or "rookMovedBlackH"
            end

            -- 3 for queenside, 7 for kingside
            local kingNewCollumn = endCollumn == 1 and 3 or 7
            -- 4 for queenside, 6 for kingside
            local rookNewCollumn = endCollumn == 1 and 4 or 6

            if endCollumn == 7 then
                endCollumn = 8
            elseif endCollumn == 1 then
                endCollumn = 2
            end

            if info[kingMovedDictIndex] == false and info[rookMovedDictIndex] == false and pathCheck(startRow, startCollumn, endRow, endCollumn) and startCollumn == endCollumn then

                info[kingMovedDictIndex] = true
                info[rookMovedDictIndex] = true

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

        -- rook moves
        if startPiece:lower() == "r" then
            if (startRow == endRow) or (startCollumn == endCollumn) then
                if pathCheck(startRow, startCollumn, endRow, endCollumn) then

                    -- for castling
                    if isCurrentPieceWhite then
                        info[endCollumn == 1 and "rookMovedWhiteA" or "rookMovedWhiteH"] = true
                    else
                        info[endCollumn == 1 and "rookMovedBlackA" or "rookMovedBlackH"] = true
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
    end
end

-- all valid moves for given piece at row collumn in {1-8, 1-8} format
function getAllValidMovesForPiece(board, info, row, collumn)
    local moves = {}

    -- 8x8 = 64 or the total number of squares on a board
    -- brute force check all squares
    -- performance implications? idk lol and who cares it's chess
    for rowIndex = 1, 8 do
        for collumnIndex = 1, 8 do
            -- simulate moving to this piece
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

    -- clear
    helpers.destroyDescendants(board.Pieces)
    helpers.destroyDescendants(board.Circles)

    -- for every square on board
    for rowIndex, row in ipairs(position) do
        for collumnIndex, piece in ipairs(row) do
            if piece ~= "" then
                -- generate a new piece and color it as well as tying displaying moves to its click
                local pieceMesh = ReplicatedStorage.Pieces[piece:lower()]:Clone()
                pieceMesh.CFrame = board[rowIndex][collumnIndex].CFrame * CFrame.new(Vector3.new(0, pieceMesh.Size.Y / 2, 0))
                
                -- set piece color
                if pieceIsWhite(piece) then
                    pieceMesh.ClickDetector.MaxActivationDistance = 0
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

    isCurrentPieceWhite = (currentPlayer == "w")

    -- checkmate is not possible if not already in check
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

                    if newBoard and not isInCheck(newBoard, simulatedInfo, isCurrentPieceWhite) then
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
-- stalemate in this is no valid moves on board
-- stalemate in chess is no valid moves on board AND not in checkmate
-- this is always ran AFTER the checkmate check, so we already know it's not mate
local function isStalemate(board, info)
    local currentPlayer = info["nextPlayer"]
    local isCurrentPieceWhite

    isCurrentPieceWhite = (currentPlayer == "w")

    for row = 1, 8 do
        for col = 1, 8 do
            local piece = board[row][col]
            
            -- check if the piece belongs to the current player
            if piece ~= "" and (pieceIsWhite(piece) == isCurrentPieceWhite) then
                local validMoves = getAllValidMovesForPiece(board, info, row, col)

                -- if any piece on your team can move
                -- you are not in stalemate
                if #validMoves > 0 then
                    return false
                end
            end
        end
    end

    return not isInCheck(board, info)
end

-- chess algebraic notation to coords on board
local function algebraicToCoords(move)
    -- subtract result from 9 because stockfish API counts rows differently
    -- row 1 on game board would be 8 on stockfish
    local colLetterStart = move:sub(1, 1)  -- 1st column letter
    local rowStart = 9 - tonumber(move:sub(2, 2))  -- 1st row number

    local colLetterEnd = move:sub(3, 3)  -- 2nd column letter
    local rowEnd = 9 - tonumber(move:sub(4, 4))  -- 2nd row number

    -- convert column letters to numbers
    local startCol = string.byte(colLetterStart) - string.byte("a") + 1
    local endCol = string.byte(colLetterEnd) - string.byte("a") + 1

    return rowStart, startCol, rowEnd, endCol
end

local function callStockfish()
    local HttpService = game:GetService("HttpService")

    local FEN = positionAndInfoToFEN(chess.chessGamePosition, chess.chessGameInfo)
    local depth = 10 -- stockfish depth, 10-19 integer

    -- sanitize url
    -- replace all nonallowed chars
    local function urlencode(str)
        str = string.gsub(str, "([^%w _%%%-%.~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        return string.gsub(str, " ", "+")
    end

    -- api
    local baseUrl = "https://stockfish.online/api/s/v2.php"
    local url = baseUrl .. "?fen=" .. urlencode(FEN) .. "&depth=" .. depth

    local success, result = pcall(function()
        return HttpService:GetAsync(url, true)
    end)

    print(success)

    -- handle the result
    if success then
        local decodedResult = HttpService:JSONDecode(result)
        local continuation = decodedResult["continuation"]
        local firstMove = string.match(continuation, "%w%d%w%d")

        print(firstMove)
        return firstMove
    else
        warn("request failed:", result)
    end
end

-- theres like 3 functions related to making moves and i dont think anyone else working
-- on this would be able to tell what's what
-- this is to handle the player moving to a known valid square and handling gamestate
-- already known to be valid because this is called by the displayValidMovesForPiece function on
-- circle click
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
        chess.chessGameInfo.nextPlayer = (chess.chessGameInfo.nextPlayer == "w") and "b" or "w"

        -- final checks for checkmate and stalemate
        if isCheckmate(chess.chessGamePosition, chess.chessGameInfo) then
            print("Checkmate")
        end

        if isStalemate(chess.chessGamePosition, chess.chessGameInfo) then
            print("Stalemate")
        end

        if chess.chessGameInfo.nextPlayer == "w" then
            makeMove(algebraicToCoords(callStockfish()))
        end
    end
end

-- red circles on where we can move
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
    makeMove(algebraicToCoords(callStockfish()))
end

return chess