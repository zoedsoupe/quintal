defmodule QuintalWeb.ErrorHTML do
  @moduledoc """
  Páginas de erro do quintal.

  O 404 é território do axô (spec 7.6): "o axô procurou, procurou... e
  não achou essa página". 401 e 500 dividem o mesmo palco quieto, com a
  microcopy de erro da casa (spec 7.7). Sem layout de app aqui, o erro
  precisa renderizar mesmo com o resto da casa fora do ar, então o
  estilo é embutido e mínimo, no preset papel.
  """

  use QuintalWeb, :html

  embed_templates "error_html/*"

  def render("401.html", assigns), do: unauthorized(assigns)
  def render("404.html", assigns), do: not_found(assigns)
  def render("500.html", assigns), do: internal_error(assigns)
  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end
