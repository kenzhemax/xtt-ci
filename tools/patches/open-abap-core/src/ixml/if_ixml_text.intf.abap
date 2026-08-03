INTERFACE if_ixml_text PUBLIC.
  " local-abap addition: text node interface (pure alias over if_ixml_node),
  " required by consumers like bizhuka/xtt (document->create_text)
  INTERFACES if_ixml_node.

  ALIASES get_value FOR if_ixml_node~get_value.
  ALIASES set_value FOR if_ixml_node~set_value.
ENDINTERFACE.
