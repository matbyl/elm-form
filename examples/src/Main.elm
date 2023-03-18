module Main exposing (main)

import Browser
import Form
import Form.Field as Field
import Form.FieldStatus exposing (FieldStatus)
import Form.FieldView as FieldView
import Form.State
import Form.Validation as Validation
import Html exposing (Html, div)
import Html.Attributes
import Pages.FormState
import Username exposing (Username)


type Msg
    = FormMsg (Form.State.Msg Msg)
    | OnSubmit { fields : List ( String, String ), parsed : Result () SignUpForm }


type alias Flags =
    ()


main : Program Flags Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


type alias Model =
    { pageFormState :
        -- TODO move `Pages.FormState.PageFormState` type into a nicer module name (and one that is exposed)
        Pages.FormState.PageFormState
    , isTransitioning : Bool
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { pageFormState =
            -- TODO move `Form.Msg.init` into a different module... `Form.State`?
            Form.State.init
      , isTransitioning = False
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnSubmit parsed ->
            let
                _ =
                    Debug.log "OnSubmit!" parsed
            in
            ( model, Cmd.none )

        FormMsg formMsg ->
            let
                ( updatedFormModel, cmd ) =
                    -- TODO move `Form.Msg.update` into a different module... `Form.State`?
                    Form.State.update formMsg model.pageFormState
            in
            ( { model | pageFormState = updatedFormModel }, cmd )


view : Model -> Browser.Document Msg
view model =
    { title = "elm-form demo"
    , body =
        [ div []
            [ signUpForm
                |> Form.withOnSubmit OnSubmit
                |> Form.renderHtml "form"
                    []
                    -- TODO get rid of errorData argument (completely, or just for vanilla apps)
                    (\_ -> Nothing)
                    -- TODO for vanilla apps, ideally user passes in `model.pageFormState` instead of this record
                    { path = []
                    , isTransitioning = model.isTransitioning
                    , pageFormState = model.pageFormState
                    }
                    ()
                |> Html.map FormMsg
            ]
        ]
    }


signUpForm : Form.HtmlForm String SignUpForm input msg
signUpForm =
    (\username password passwordConfirmation ->
        { combine =
            Validation.succeed SignUpForm
                |> Validation.andMap
                    (username
                        |> Validation.map Username.fromString
                        |> Validation.fromResult
                    )
                |> Validation.andMap
                    (Validation.map2
                        (\passwordValue passwordConfirmationValue ->
                            if passwordValue == passwordConfirmationValue then
                                Validation.succeed passwordValue

                            else
                                Validation.fail "Must match password" passwordConfirmation
                        )
                        password
                        passwordConfirmation
                        |> Validation.andThen identity
                    )
        , view =
            \formState ->
                let
                    fieldView label field =
                        Html.div []
                            [ Html.label
                                []
                                [ Html.text (label ++ " ")
                                , FieldView.input [] field
                                , errorsView formState.submitAttempted formState.errors field
                                ]
                            ]
                in
                [ fieldView "username" username
                , fieldView "Password" password
                , fieldView "Password Confirmation" passwordConfirmation
                , if formState.isTransitioning then
                    Html.button
                        [ Html.Attributes.disabled True ]
                        [ Html.text "Signing Up..." ]

                  else
                    Html.button [] [ Html.text "Sign Up" ]
                ]
        }
    )
        |> Form.init
        |> Form.field "username" (Field.text |> Field.required "Required")
        |> Form.field "password" (Field.text |> Field.password |> Field.required "Required")
        |> Form.field "password-confirmation" (Field.text |> Field.password |> Field.required "Required")


type alias SignUpForm =
    { username : Username, password : String }


errorsView :
    Bool
    -> Form.Errors String
    -> Validation.Field String parsed kind
    -> Html msg
errorsView submitAttempted errors field =
    if submitAttempted || Validation.statusAtLeast Form.FieldStatus.Blurred field then
        -- only show validations when a field has been blurred
        -- (it can be annoying to see errors while you type the initial entry for a field, but we want to see the current
        -- errors once we've left the field, even if we are changing it so we know once it's been fixed or whether a new
        -- error is introduced)
        errors
            |> Form.errorsForField field
            |> List.map (\error -> Html.li [ Html.Attributes.style "color" "red" ] [ Html.text error ])
            |> Html.ul []

    else
        Html.ul [] []
