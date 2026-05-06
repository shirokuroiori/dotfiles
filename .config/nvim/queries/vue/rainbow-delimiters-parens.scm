;;; Vue: HTMLタグを除外し、mustache interpolationのみ対象
;;; スクリプト内の括弧は埋め込みJS/TSパーサーが担当するため不要

(interpolation
  "{{" @delimiter
  "}}" @delimiter) @container
