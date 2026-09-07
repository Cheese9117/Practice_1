module Main where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import Data.ByteString (ByteString)
import Data.Bits (testBit)
import Data.Word (Word8)
import Data.List (intercalate)
import Text.Printf (printf)

-- ------------------------------------------------------------
-- 1. Estructura de datos para la imagen PBM ya cargada
-- ------------------------------------------------------------

data Imagen = Imagen
  { ancho     :: Int
  , alto      :: Int
  , bytesFila :: Int        -- bytes por fila (ceil(ancho/8))
  , pixeles   :: ByteString -- datos binarios ya "desempacados" del encabezado
  }

rutaArchivo :: FilePath
rutaArchivo = "../curva_binaria_P4.pbm"

-- ------------------------------------------------------------
-- 2. Carga y parseo del archivo PBM P4 (binario)
-- ------------------------------------------------------------

cargarPBM :: FilePath -> IO Imagen
cargarPBM ruta = do
  contenido <- BS.readFile ruta
  let (w, h, datos) = parsearEncabezado contenido
      bpr            = (w + 7) `div` 8
  return (Imagen w h bpr datos)

-- Separa la cabecera de texto de los datos binarios y extrae ancho/alto.
parsearEncabezado :: ByteString -> (Int, Int, ByteString)
parsearEncabezado bs0 =
  let bs1        = BS.drop 2 bs0                 -- descarta "P4"
      bs2        = saltarBlancosYComentarios bs1
      Just (w, bs3) = C8.readInt bs2
      bs4        = saltarBlancosYComentarios bs3
      Just (h, bs5) = C8.readInt bs4
      datos      = BS.drop 1 bs5                 -- 1 solo separador antes del binario
  in (w, h, datos)

-- Salta espacios en blanco y líneas de comentario ("# ...") de forma recursiva,
-- tal como exige el estándar de archivos PBM.
saltarBlancosYComentarios :: ByteString -> ByteString
saltarBlancosYComentarios bs = case BS.uncons bs of
  Nothing -> bs
  Just (c, resto)
    | esBlanco c    -> saltarBlancosYComentarios resto
    | c == almohadilla -> saltarBlancosYComentarios (C8.dropWhile (/= '\n') bs)
    | otherwise     -> bs
  where
    esBlanco w = w `elem` ([32, 9, 10, 13] :: [Word8])
    almohadilla = 35

-- ------------------------------------------------------------
-- 3. Acceso a píxeles individuales: bit -> negro/blanco
-- ------------------------------------------------------------

-- 1 = región bajo la curva (negro), 0 = exterior (blanco)
esNegro :: Imagen -> Int -> Int -> Bool
esNegro img x y = testBit byte bitPos
  where
    idx    = y * bytesFila img + (x `div` 8)
    byte   = BS.index (pixeles img) idx
    bitPos = 7 - (x `mod` 8)   -- el bit más significativo es el píxel más a la izquierda

-- ------------------------------------------------------------
-- 4. La función discreta f(x): píxeles negros consecutivos
--    contados desde la fila inferior hacia arriba.
-- ------------------------------------------------------------

f :: Imagen -> Int -> Int
f img x = length (takeWhile id [esNegro img x y | y <- [alto img - 1, alto img - 2 .. 0]])

-- ------------------------------------------------------------
-- 5. M = [f(0), f(1), ..., f(n-1)]  y  area = sum M
-- ------------------------------------------------------------

calcularM :: Imagen -> [Int]
calcularM img = map (f img) [0 .. ancho img - 1]

calcularArea :: [Int] -> Int
calcularArea = sum

-- ------------------------------------------------------------
-- 6. Visualización en consola de la curva binaria original
-- ------------------------------------------------------------

anchoConsola, altoConsola :: Int
anchoConsola = 100
altoConsola  = 28

-- Toma `n` muestras uniformemente distribuidas en [0, largo-1]
muestrear :: Int -> Int -> [Int]
muestrear largo n
  | n >= largo = [0 .. largo - 1]
  | otherwise  = [ (i * (largo - 1)) `div` (n - 1) | i <- [0 .. n - 1] ]

dibujarCurva :: [Int] -> String
dibujarCurva m = intercalate "\n" (map dibujarFila [altoConsola, altoConsola - 1 .. 1])
  where
    maxH = maximum m
    indicesMuestra = muestrear (length m) anchoConsola
    alturasMuestra = map (m !!) indicesMuestra
    alturasEscaladas = map escalar alturasMuestra
    escalar h = round (fromIntegral h * fromIntegral altoConsola / fromIntegral maxH :: Double) :: Int
    dibujarFila fila = [ if h >= fila then '#' else ' ' | h <- alturasEscaladas ]

-- ------------------------------------------------------------
-- 7. Visualización de la función de alturas M[x] = f(x)
-- ------------------------------------------------------------

rampaAscii :: String
rampaAscii = " .:-=+*#%@"

dibujarSparkline :: [Int] -> String
dibujarSparkline m = map nivel alturasMuestra
  where
    maxH = maximum m
    indicesMuestra = muestrear (length m) anchoConsola
    alturasMuestra = map (m !!) indicesMuestra
    nNiveles = length rampaAscii - 1
    nivel h = rampaAscii !! round (fromIntegral h * fromIntegral nNiveles / fromIntegral maxH :: Double)

-- ------------------------------------------------------------
-- 8. Valores de muestra x_i -> f(x_i)
-- ------------------------------------------------------------

valoresMuestra :: [Int] -> [(Int, Int)]
valoresMuestra m = [ (x, m !! x) | x <- muestrear (length m) 10 ]

-- ------------------------------------------------------------
-- Main
-- ------------------------------------------------------------

main :: IO ()
main = do
  img <- cargarPBM rutaArchivo
  let m    = calcularM img
      area = calcularArea m

  printf "Imagen: %d x %d pixeles\n" (ancho img) (alto img)
  printf "Area = %d pixeles cuadrados\n\n" area

  putStrLn "VISUALIZACION DE LA CURVA (muestreada y reescalada a la consola):"
  putStrLn (dibujarCurva m)
  putStrLn ""

  putStrLn "FUNCION DE ALTURAS M[x] = f(x):"
  putStrLn (dibujarSparkline m)
  putStrLn ""

  putStrLn "ALGUNOS VALORES x_i -> f(x_i):"
  mapM_ (\(i, (x, h)) -> printf "x_%d = %d -> f(x_%d) = %d pixeles\n" (i :: Int) x i h)
        (zip [0 ..] (valoresMuestra m))
