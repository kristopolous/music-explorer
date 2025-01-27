function quote(str) {
  gsub(/"/, "\"\"", str);  
  return "\"" str "\"";    
}
{
  OFS=",";
  date=$1
  formatted_date = substr(date, 1, 4) "-" substr(date, 5, 2) "-" substr(date, 7, 2) " 00:00:00"
  path=substr($0, 9);
  print quote($5), quote($6), quote($7), quote(path), quote(formatted_date)
}
