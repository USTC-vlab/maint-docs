document.addEventListener("DOMContentLoaded", function() {
  load_navpane();
});

function load_navpane() {
  var width = window.innerWidth;
  if (width <= 1200)
    return;

  var nav = document.getElementsByClassName("md-nav__toggle");
  for (var i = 0; i < nav.length; i++) {
    if ((nav.item(i).id.match(/_\d/g) || []).length > 1)
      continue;
    nav.item(i).checked = true;
  }
}
