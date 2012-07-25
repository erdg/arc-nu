(mac in-unicode-range? (x . body)
  (w/uniq u
    `(when ,x
       (let ,u (coerce ,x 'int)
         (or ,@(mappend (fn (x)
                          (if acons.x
                            (collect:let (l r) x
                              (for i (coerce string.l 'int 16)
                                     (coerce string.r 'int 16)
                                (yield `(is ,u ,i))))
                            (list `(is ,u ,(coerce string.x 'int 16)))))
                        body))))))

(def nuit-always-illegal? (c)
  (in-unicode-range? c
    (0 8)
    (B C)
    (E 1F)
    7F
    (80 84)
    (86 9F)
    ;; TODO this causes it to take a long time to start-up
    ;(D800 DFFF)
    (FFFE FFFF)))

(def nuit-illegal-at-start? (c)
  (in-unicode-range? c
    9
    20
    85
    A0
    1680
    180E
    (2000 200A)
    (2028 2029)
    202F
    205F
    3000))


(= nuit-fail (uniq))

(def split-whitespace (str)
  (awith (x    str
          acc  nil)
    (if (no x)
          (list (and acc (string rev.acc)) nil)
        (is car.x #\space)
          (list (and acc (string rev.acc))
                (do (while (is car.x #\space)
                      (zap cdr x))
                    (and x (string x))))
        (self cdr.x (cons car.x acc)))))

(def nuit-first-value (reify)
  (alet x nil
    (or x (self:reify:fn (parse next x)
            (if cdr.x
                x
                (do (next) nil))))))

(def block-indent (err reify new (o end) (o f))
  (let oend nil
    (collect:while:reify:fn (parse next x)
      (when x
        (if (>= car.x new)
              (do (if oend (do (yield oend)
                               (= oend nil))
                           (yield end))
                  (yield (newstring (- car.x new) #\space))
                  (if f (yield (f err new cdr.x))
                        (yield cdr.x))
                  (next)
                  t)
            (no cdr.x)
              (do (= oend #\newline)
                  (yield #\newline)
                  (next)
                  t))))))

(mac find-indent (s i)
  (w/uniq u
    `(let ,u (+ ,i 1)
       (while (is (car ,s) #\space)
         (++ ,u)
         (zap cdr ,s))
       ,u)))

(def hexadecimal? (c)
  (in c #\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9
        #\a #\b #\c #\d #\e #\f
        #\A #\B #\C #\D #\E #\F))

(def nuit-parse-unicode (err self rest i)
  (if (is car.rest #\()
      (do (++ i)
          (zap cdr rest)
          (join (awith ()
                  (let x (collect:while (hexadecimal? car.rest)
                           (yield car.rest)
                           (++ i)
                           (zap cdr rest))
                    (let x (when x
                             (coerce (coerce string.x 'int 16) 'char))
                      (if (is car.rest #\space)
                            (do (++ i)
                                (zap cdr rest)
                                (cons x (self)))
                          (is car.rest #\))
                            (do (++ i)
                                (zap cdr rest)
                                (list x))
                          (no rest)
                            (err (string "missing ending )") (+ i 1))
                          (err (string "illegal Unicode escape " car.rest) (+ i 1))))))
                (self rest i)))
      (self rest i)
      (err (string "illegal Unicode escape " car.rest) (+ i 1))))

(def transform-quote (err i s)
  (awith (s  s
          i  i)
    (whenlet (c . rest) s
      (if (is c #\\)
          (if (is car.rest #\\)
                (cons car.rest
                      (self cdr.rest (+ i 2)))
              (is car.rest #\u)
                (nuit-parse-unicode err self cdr.rest (+ i 1))
              (no rest)
                (list #\newline)
              (err (string "illegal escape " car.rest) (+ i 1)))
          (cons c (self rest (+ i 1)))))))

(def block-string (err reify i s end (o f))
  (let new (find-indent s i)
    (let s (if f (f err new s)
                 s)
      (string s
        (block-indent err reify new end f)))))

(= parsers (obj #\` (fn (err reify i s)
                      (block-string err reify i s #\newline))
                #\" (fn (err reify i s)
                      (block-string err reify i s #\space transform-quote))
                #\# (fn (err reify i s)
                      (block-indent err reify (find-indent s i))
                      nuit-fail)
                #\\ (fn (err reify i s)
                      (if (parsers car.s)
                          string.s
                          (err (string "invalid escape sequence \\" car.s) 1)))
                #\@ (fn (err reify i s)
                      (let (first second) split-whitespace.s
                        (withs (new   (car:nuit-first-value reify)
                                body  (when (> new i)
                                        (collect:while:reify:fn (parse next x)
                                          (when x
                                            (if (no cdr.x)
                                                  (do (next) t)
                                                (is car.x new)
                                                  (let x (parse (next) new)
                                                    (if (is x nuit-fail)
                                                        t
                                                        (yield x))))))))
                          (if first
                              (if second
                                  (list* first second body)
                                  (cons first body))
                              (if second
                                  (cons second body)
                                  body)))))))

(def nuit-parse-whitespace (line s)
  (let indent 0
    (while (is peekc.s #\space)
      (++ indent)
      (readc s))
    (if (and (> indent 0)
             (in peekc.s #\newline #\return))
      (formatted-err "illegal whitespace" (newstring indent #\space) line indent))
    indent))

(def nuit-string-newline (line s)
  (let acc nil
    (while (no:in peekc.s nil #\newline #\return)
      (let c readc.s
        (if (nuit-always-illegal? c)
            (err (string "illegal character" c))
            (push c acc))))
    (if (is car.acc #\space)
        (formatted-err "illegal whitespace" rev.acc line len.acc)
        (rev acc))))

(def nuit-strip-newline (s)
  (case peekc.s
    #\newline (readc s)
    #\return  (do (readc s)
                  (when (is peekc.s #\newline)
                    (readc s)))))

(def nuit-chunk (s)
  (let line 0
    (collect:while peekc.s
      (++ line)
      (withs (new  (nuit-parse-whitespace line s)
              str  (nuit-string-newline line s))
        (nuit-strip-newline s)
        (yield:cons new str)))))

(def formatted-err (message str lines column)
  (err:string message "\n  " str
    "  (line " lines ", column " column ")\n "
    (newstring column #\space) "^"))

(def f-err (message lines i c s (o offset 0))
  (formatted-err message
    (string (newstring i #\space) (cons c s))
    lines
    (if (is i 0)
        (+ 1 offset)
        (+ i offset))))

(def nuit-parse1 (l)
  (with (lines  0
         next   nil
         parse  nil
         reify  nil
         stack  nil)
    (def next ()
      (++ lines)
      (let x car.l
        (zap cdr l)
        x))
    (def parse (x (o new))
      (when new
        (push new stack))
      (whenlet (i c . s) x
        (aif (no c)
               (parse (next) new)
             (no:some [is i _] stack)
               (f-err "illegal indentation" lines i c s)
             (nuit-illegal-at-start? c)
               (f-err (string "illegal character at start of line " c)
                      lines i c s)
             (parsers c)
               (it (fn (message (o offset 0))
                     (f-err message lines i c s offset))
                   reify i s)
             (string:cons c s))))
    (def reify (body)
      (body parse next car.l))
    (collect:while l
      (= stack (list 0))
      (let x (parse:next)
        (unless (is x nuit-fail)
          (yield x))))))

(def nuit-parse (s)
  (let s (if (isa s 'string)
             (instring s)
             s)
    (nuit-parse1 nuit-chunk.s)))